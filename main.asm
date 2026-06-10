section .data
    wsaData times 400 db 0
    serverAddr times 16 db 0
    
    startMsg db "WebSocket Server Starting...", 0xD, 0xA, 0
    wsaInitMsg db "WSA Initialized", 0xD, 0xA, 0
    socketCreatedMsg db "Socket Created", 0xD, 0xA, 0
    bindMsg db "Socket Bound", 0xD, 0xA, 0
    listenMsg db "Listening on port 8080...", 0xD, 0xA, 0
    clientConnectMsg db "Client connected!", 0xD, 0xA, 0
    handshakeSentMsg db "Handshake sent!", 0xD, 0xA, 0
    dataReceivedMsg db "Data received!", 0xD, 0xA, 0
    echoSentMsg db "Echo sent!", 0xD, 0xA, 0
    
    wsResponse db "HTTP/1.1 101 Switching Protocols", 0xD, 0xA
               db "Upgrade: websocket", 0xD, 0xA
               db "Connection: Upgrade", 0xD, 0xA
               db "Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=", 0xD, 0xA
               db 0xD, 0xA
    wsResponseLen equ $ - wsResponse
    
section .bss
    listenSocket resd 1
    clientSocket resd 1
    hStdOut resd 1
    bytesWritten resd 1
    recvBuffer resb 4096
    sendBuffer resb 4096
    
section .text
    global _start
    extern _WSAStartup@8, _socket@12, _bind@12, _listen@8, _accept@12
    extern _closesocket@4, _WSACleanup@0, _GetStdHandle@4
    extern _WriteConsoleA@20, _ExitProcess@4, _recv@16, _send@16

_start:
    push -11
    call _GetStdHandle@4
    mov [hStdOut], eax
    
    push startMsg
    call PrintString
    
    push wsaData
    push 0x0202
    call _WSAStartup@8
    test eax, eax
    jnz error_exit
    
    push wsaInitMsg
    call PrintString
    
    push 6
    push 1
    push 2
    call _socket@12
    cmp eax, -1
    je error_exit
    mov [listenSocket], eax
    
    push socketCreatedMsg
    call PrintString
    
    mov word [serverAddr], 2
    mov word [serverAddr + 2], 0x901F
    mov dword [serverAddr + 4], 0
    
    push 16
    push serverAddr
    push dword [listenSocket]
    call _bind@12
    test eax, eax
    jnz error_exit
    
    push bindMsg
    call PrintString
    
    push 5
    push dword [listenSocket]
    call _listen@8
    test eax, eax
    jnz error_exit
    
    push listenMsg
    call PrintString

accept_loop:
    push 0
    push 0
    push dword [listenSocket]
    call _accept@12
    cmp eax, -1
    je accept_loop
    mov [clientSocket], eax
    
    push clientConnectMsg
    call PrintString
    
    push 0
    push 4096
    push recvBuffer
    push dword [clientSocket]
    call _recv@16
    cmp eax, 0
    jle close_client
    
    push 0
    push wsResponseLen
    push wsResponse
    push dword [clientSocket]
    call _send@16
    
    push handshakeSentMsg
    call PrintString
    
message_loop:
    push 0
    push 4096
    push recvBuffer
    push dword [clientSocket]
    call _recv@16
    
    cmp eax, 0
    jle close_client
    
    push dataReceivedMsg
    call PrintString
    
    movzx ecx, byte [recvBuffer + 1]
    and ecx, 0x7F  ; Get payload length (ignore mask bit)
    
    test byte [recvBuffer + 1], 0x80
    jz .send_echo  ; Not masked, shouldn't happen from client
    
    mov esi, recvBuffer
    add esi, 6
    
    mov edi, sendBuffer
    add edi, 2  ; Leave room for header
    
    xor edx, edx
.unmask_loop:
    cmp edx, ecx
    jge .send_echo
    
    mov al, [esi + edx]
    lea ebx, [recvBuffer + 2]
    mov bl, [ebx + edx]
    and ebx, 3  ; edx & 3
    mov bl, [recvBuffer + 2 + ebx]
    xor al, bl
    mov [edi + edx], al
    
    inc edx
    jmp .unmask_loop
    
.send_echo:
    mov byte [sendBuffer], 0x81  ; FIN + text frame
    mov [sendBuffer + 1], cl  ; Payload length (unmasked, no mask bit)
    
    mov ebx, ecx
    add ebx, 2  ; header size
    
    push 0
    push ebx
    push sendBuffer
    push dword [clientSocket]
    call _send@16
    
    push echoSentMsg
    call PrintString
    
    jmp message_loop

close_client:
    push dword [clientSocket]
    call _closesocket@4
    jmp accept_loop

error_exit:
    push dword [listenSocket]
    call _closesocket@4
    call _WSACleanup@0
    push 0
    call _ExitProcess@4

PrintString:
    push ebp
    mov ebp, esp
    push ebx
    push esi
    mov esi, [ebp + 8]
    xor ecx, ecx
.count_loop:
    cmp byte [esi + ecx], 0
    je .do_print
    inc ecx
    jmp .count_loop
.do_print:
    push 0
    push bytesWritten
    push ecx
    push esi
    push dword [hStdOut]
    call _WriteConsoleA@20
    pop esi
    pop ebx
    pop ebp
    ret 4
