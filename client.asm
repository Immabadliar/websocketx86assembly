section .data
    wsaData times 400 db 0
    serverAddr times 16 db 0
    
    startMsg db "WebSocket Client Starting...", 0xD, 0xA, 0
    connectingMsg db "Connecting to localhost:8080...", 0xD, 0xA, 0
    connectedMsg db "Connected!", 0xD, 0xA, 0
    sentMsg db "Sent message!", 0xD, 0xA, 0
    receivedMsg db "Received: ", 0
    errorMsg db "Error!", 0xD, 0xA, 0
    
    handshake db "GET / HTTP/1.1", 0xD, 0xA
              db "Host: localhost:8080", 0xD, 0xA
              db "Upgrade: websocket", 0xD, 0xA
              db "Connection: Upgrade", 0xD, 0xA
              db "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==", 0xD, 0xA
              db "Sec-WebSocket-Version: 13", 0xD, 0xA
              db 0xD, 0xA
    handshakeLen equ $ - handshake
    
    testMsg db "Hello from x86 client!"
    testMsgLen equ $ - testMsg
    
section .bss
    clientSocket resd 1
    hStdOut resd 1
    bytesWritten resd 1
    recvBuffer resb 4096
    sendFrame resb 512
    
section .text
    global _start
    extern _WSAStartup@8, _socket@12, _connect@12, _send@16, _recv@16
    extern _closesocket@4, _WSACleanup@0, _GetStdHandle@4
    extern _WriteConsoleA@20, _ExitProcess@4, _htons@4, _inet_addr@4

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
    
    push 6
    push 1
    push 2
    call _socket@12
    cmp eax, -1
    je error_exit
    mov [clientSocket], eax
    
    push connectingMsg
    call PrintString
    
    mov word [serverAddr], 2        ; AF_INET
    
    push 8080
    call _htons@4
    mov word [serverAddr + 2], ax
    
    ; localhost = 127.0.0.1
    mov dword [serverAddr + 4], 0x0100007F
    

    push 16
    push serverAddr
    push dword [clientSocket]
    call _connect@12
    test eax, eax
    jnz error_exit
    
    push connectedMsg
    call PrintString
    
    push 0
    push handshakeLen
    push handshake
    push dword [clientSocket]
    call _send@16
    
    push 0
    push 4096
    push recvBuffer
    push dword [clientSocket]
    call _recv@16
    
    mov esi, recvBuffer
    mov ecx, 100
.check_101:
    cmp word [esi], 0x3031  ; "10"
    jne .next_char
    cmp byte [esi+2], 0x31  ; "1"
    je .handshake_ok
.next_char:
    inc esi
    loop .check_101
    jmp error_exit
    
.handshake_ok:
    mov edi, sendFrame

    mov byte [edi], 0x81
    inc edi
    
    mov al, 0x80                  
    or al, testMsgLen
    mov [edi], al
    inc edi
    
    mov dword [edi], 0
    add edi, 4
    
    mov esi, testMsg
    mov ecx, testMsgLen
    rep movsb
    
    mov ecx, testMsgLen
    add ecx, 6                  
    
    push 0
    push ecx
    push sendFrame
    push dword [clientSocket]
    call _send@16
    
    push sentMsg
    call PrintString
    
    push 0
    push 4096
    push recvBuffer
    push dword [clientSocket]
    call _recv@16
    
    cmp eax, 0
    jle cleanup
    
    push receivedMsg
    call PrintString
    
    movzx ecx, byte [recvBuffer + 1]
    and ecx, 0x7F
    
    push 0
    push bytesWritten
    push ecx
    lea eax, [recvBuffer + 2]
    push eax
    push dword [hStdOut]
    call _WriteConsoleA@20
    
    push newlineMsg
    call PrintString
    
cleanup:
    push dword [clientSocket]
    call _closesocket@4
    call _WSACleanup@0
    push 0
    call _ExitProcess@4

error_exit:
    push errorMsg
    call PrintString
    jmp cleanup

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

section .data
newlineMsg db 0xD, 0xA, 0
