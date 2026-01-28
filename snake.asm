IDEAL
MODEL TINY
CODESEG
ORG 100h

start:
    ; Set up segments for COM file
    mov ax, cs
    mov ds, ax
    
    ; Set Video Mode 03h (80x25 Text)
    mov ax, 0003h
    int 10h

    ; Hide Cursor
    mov ah, 01h
    mov cx, 2607h
    int 10h

    ; ES points to Video Memory (B800h)
    mov ax, 0B800h
    mov es, ax

    ; --- Initialize Snake Position ---
    ; We manually set the first 3 segments to avoid array offset issues
    
    ; Head (Index 0) at 40, 12
    lea bx, [SnakeX]
    mov [byte ptr bx], 40
    lea bx, [SnakeY]
    mov [byte ptr bx], 12
    
    ; Body (Index 1) at 39, 12
    lea bx, [SnakeX]
    mov [byte ptr bx+1], 39
    lea bx, [SnakeY]
    mov [byte ptr bx+1], 12
    
    ; Tail (Index 2) at 38, 12
    lea bx, [SnakeX]
    mov [byte ptr bx+2], 38
    lea bx, [SnakeY]
    mov [byte ptr bx+2], 12
    
    mov [SnakeLen], 3
    mov [CurrentDir], 4        ; Start moving Right

    ; Initial Draw
    call DrawSnake
    call CreateFood

; =========================================================
; Main Game Loop
; =========================================================
GameLoop:

    ; --- Delay Loop ---
    mov cx, 02h          ; Speed adjustment (increase to slow down)
DelayOut:
    mov dx, 0FFFFh
DelayIn:
    dec dx
    jnz DelayIn
    loop DelayOut

    ; --- Input Handling ---
    mov ah, 01h          ; Check keyboard buffer
    int 16h
    jz MoveLogic         ; No key pressed, continue movement
    
    mov ah, 00h          ; Get key
    int 16h
    
    ; WASD Controls
    cmp al, 'w'
    je DirUp
    cmp al, 's'
    je DirDown
    cmp al, 'a'
    je DirLeft
    cmp al, 'd'
    je DirRight
    jmp MoveLogic

DirUp:
    cmp [CurrentDir], 2  ; Prevent 180 turn
    je MoveLogic
    mov [CurrentDir], 1
    jmp MoveLogic
DirDown:
    cmp [CurrentDir], 1
    je MoveLogic
    mov [CurrentDir], 2
    jmp MoveLogic
DirLeft:
    cmp [CurrentDir], 4
    je MoveLogic
    mov [CurrentDir], 3
    jmp MoveLogic
DirRight:
    cmp [CurrentDir], 3
    je MoveLogic
    mov [CurrentDir], 4

; =========================================================
; Game Logic
; =========================================================
MoveLogic:

    ; 1. Erase Tail
    xor bx, bx
    mov bl, [SnakeLen]
    dec bl                 ; Get tail index
    
    lea si, [SnakeX]
    mov al, [si+bx]        ; Load X
    lea si, [SnakeY]
    mov dl, [si+bx]        ; Load Y
    
    call EraseChar

    ; 2. Shift Body (Copy index i-1 to i)
    xor cx, cx
    mov cl, [SnakeLen]
    dec cl                 ; Number of shifts
    
    mov bl, cl             ; Start from end
ShiftLoop:
    ; Shift X
    lea si, [SnakeX]
    mov al, [si+bx-1]
    mov [si+bx], al
    
    ; Shift Y
    lea si, [SnakeY]
    mov al, [si+bx-1]
    mov [si+bx], al
    
    dec bx
    loop ShiftLoop

    ; 3. Update Head Position
    lea si, [SnakeX]
    mov al, [si]
    lea si, [SnakeY]
    mov dl, [si]
    
    cmp [CurrentDir], 1
    je GoUp
    cmp [CurrentDir], 2
    je GoDown
    cmp [CurrentDir], 3
    je GoLeft
    cmp [CurrentDir], 4
    je GoRight

GoUp:    dec dl
         jmp CheckHit
GoDown:  inc dl
         jmp CheckHit
GoLeft:  dec al
         jmp CheckHit
GoRight: inc al

; =========================================================
; Collision Checks
; =========================================================
CheckHit:
    ; Wall Collision
    cmp al, 0
    jl GameOver
    cmp al, 80
    jge GameOver
    cmp dl, 0
    jl GameOver
    cmp dl, 25
    jge GameOver

    ; Save New Head Position
    lea si, [SnakeX]
    mov [si], al
    lea si, [SnakeY]
    mov [si], dl
    
    ; Food Collision
    cmp al, [FoodX]
    jne NoEat
    cmp dl, [FoodY]
    jne NoEat
    
    ; Eat Food
    inc [SnakeLen]
    call CreateFood

NoEat:
    call DrawHead
    jmp GameLoop

; =========================================================
; Exit Routine
; =========================================================
GameOver:
    mov ax, 0003h        ; Clear Screen
    int 10h
    
    mov dx, offset MsgOver
    mov ah, 09h
    int 21h
    
    mov ax, 4c00h
    int 21h

; =========================================================
; Procedures
; =========================================================

PROC DrawHead
    lea si, [SnakeX]
    mov al, [si]
    lea si, [SnakeY]
    mov dl, [si]
    
    mov bl, 02h          ; Green
    mov cl, '0'
    call PutPixel
    ret
ENDP DrawHead

PROC EraseChar
    mov bl, 0            ; Black
    mov cl, ' '
    call PutPixel
    ret
ENDP EraseChar

PROC PutPixel
    ; Inputs: AL=X, DL=Y, CL=Char, BL=Color
    push ax bx dx di es
    
    ; Calculate Offset: (Y * 80 + X) * 2
    xor dh, dh
    push ax
    mov al, 80
    mul dl               ; AX = Y * 80
    mov di, ax
    pop ax
    
    xor ah, ah
    add di, ax
    add di, di           ; Multiply by 2 (Char + Attribute)
    
    mov es:[di], cl      ; Draw Char
    mov es:[di+1], bl    ; Draw Color
    
    pop es di dx bx ax
    ret
ENDP PutPixel

PROC DrawSnake
    xor cx, cx
    mov cl, [SnakeLen]
    xor bx, bx
DrLoop:
    lea si, [SnakeX]
    mov al, [si+bx]
    lea si, [SnakeY]
    mov dl, [si+bx]
    
    push bx cx
    
    mov bl, 02h
    mov cl, '0'
    call PutPixel
    
    pop cx bx
    inc bx
    loop DrLoop
    ret
ENDP DrawSnake

PROC CreateFood
    ; Generate Random via Timer
    mov ah, 00h
    int 1Ah
    
    ; Calculate X
    mov ax, dx
    xor dx, dx
    mov cx, 76
    div cx
    add dl, 2
    mov [FoodX], dl
    
    ; Calculate Y
    mov ax, dx
    add ax, [word ptr SnakeX] ; Add entropy
    xor dx, dx
    mov cx, 20
    div cx
    add dl, 2
    mov [FoodY], dl
    
    ; Draw Food
    mov al, [FoodX]
    mov dl, [FoodY]
    mov bl, 04h          ; Red
    mov cl, '*'
    call PutPixel
    ret
ENDP CreateFood

; =========================================================
; Data Section
; =========================================================
MsgOver    db 'Game Over!$'
FoodX      db ?
FoodY      db ?
CurrentDir db ?
SnakeLen   db ?
SnakeX     db 100 dup(?)
SnakeY     db 100 dup(?)

END start