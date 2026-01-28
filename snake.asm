IDEAL
MODEL TINY
CODESEG
ORG 100h

start:
    ; --- 1. Настройка сегментов (для COM файла DS=CS) ---
    mov ax, cs
    mov ds, ax
    
    ; --- 2. Видеорежим 80x25 ---
    mov ax, 0003h
    int 10h

    ; --- 3. Прячем курсор ---
    mov ah, 01h
    mov cx, 2607h
    int 10h

    ; --- 4. Настройка ES на видеопамять ---
    mov ax, 0B800h
    mov es, ax

    ; --- 5. ИНИЦИАЛИЗАЦИЯ (Самая важная часть) ---
    ; Заполняем координаты вручную через указатели, чтобы точно сработало
    
    ; Голова (index 0) = 40, 12
    lea bx, [SnakeX]
    mov [byte ptr bx], 40      ; X головы
    lea bx, [SnakeY]
    mov [byte ptr bx], 12      ; Y головы
    
    ; Тело (index 1) = 39, 12
    lea bx, [SnakeX]
    mov [byte ptr bx+1], 39
    lea bx, [SnakeY]
    mov [byte ptr bx+1], 12
    
    ; Хвост (index 2) = 38, 12
    lea bx, [SnakeX]
    mov [byte ptr bx+2], 38
    lea bx, [SnakeY]
    mov [byte ptr bx+2], 12
    
    mov [SnakeLen], 3
    mov [CurrentDir], 4        ; 4 = Вправо

    ; --- 6. Первая отрисовка ---
    call DrawSnake
    call CreateFood

; =========================================================
; ГЛАВНЫЙ ЦИКЛ
; =========================================================
GameLoop:

    ; --- A. ЗАДЕРЖКА (Delay) ---
    mov cx, 02h          ; Скорость (увеличь до 03h или 04h, если быстро)
DelayOut:
    mov dx, 0FFFFh
DelayIn:
    dec dx
    jnz DelayIn
    loop DelayOut

    ; --- B. ПРОВЕРКА КЛАВИШ ---
    mov ah, 01h          ; Есть нажатие?
    int 16h
    jz MoveLogic         ; Нет -> просто двигаем змею
    
    mov ah, 00h          ; Читаем клавишу
    int 16h
    
    ; WASD
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
    cmp [CurrentDir], 2
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
; ЛОГИКА ДВИЖЕНИЯ
; =========================================================
MoveLogic:

    ; 1. СТИРАЕМ ХВОСТ
    ; Нам нужно взять координаты последнего элемента
    xor bx, bx
    mov bl, [SnakeLen]
    dec bl                 ; Индекс хвоста
    
    lea si, [SnakeX]
    mov al, [si+bx]        ; X хвоста
    lea si, [SnakeY]
    mov dl, [si+bx]        ; Y хвоста
    
    call EraseChar         ; Стираем с экрана

    ; 2. СДВИГАЕМ ТЕЛО (Копируем координаты i-1 в i)
    xor cx, cx
    mov cl, [SnakeLen]
    dec cl                 ; Количество сдвигов
    
    ; Начинаем с хвоста
    mov bl, cl             ; bl = текущий индекс (например, 2)
ShiftLoop:
    ; X[i] = X[i-1]
    lea si, [SnakeX]
    mov al, [si+bx-1]      ; берем предыдущий
    mov [si+bx], al        ; пишем в текущий
    
    ; Y[i] = Y[i-1]
    lea si, [SnakeY]
    mov al, [si+bx-1]
    mov [si+bx], al
    
    dec bx
    loop ShiftLoop

    ; 3. ДВИГАЕМ ГОЛОВУ (Index 0)
    lea si, [SnakeX]
    mov al, [si]           ; Текущий X головы
    lea si, [SnakeY]
    mov dl, [si]           ; Текущий Y головы
    
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
; ПРОВЕРКИ
; =========================================================
CheckHit:
    ; -- Стены --
    cmp al, 0
    jl GameOver
    cmp al, 80
    jge GameOver
    cmp dl, 0
    jl GameOver
    cmp dl, 25
    jge GameOver

    ; -- Сохраняем новую голову --
    lea si, [SnakeX]
    mov [si], al
    lea si, [SnakeY]
    mov [si], dl
    
    ; -- Еда --
    cmp al, [FoodX]
    jne NoEat
    cmp dl, [FoodY]
    jne NoEat
    
    ; СЪЕЛИ!
    inc [SnakeLen]
    call CreateFood
    ; (Хвост не стирали бы, если бы логика была сложнее, 
    ; но тут просто вырастет на следующем кадре)

NoEat:
    ; Рисуем голову
    call DrawHead
    jmp GameLoop

; =========================================================
; КОНЕЦ
; =========================================================
GameOver:
    mov ax, 0003h
    int 10h
    
    mov dx, offset MsgOver
    mov ah, 09h
    int 21h
    
    mov ax, 4c00h
    int 21h

; =========================================================
; ПРОЦЕДУРЫ
; =========================================================

PROC DrawHead
    lea si, [SnakeX]
    mov al, [si]       ; X
    lea si, [SnakeY]
    mov dl, [si]       ; Y
    
    mov bl, 02h        ; Зеленый
    mov cl, '0'        ; Символ
    call PutPixel
    ret
ENDP DrawHead

PROC EraseChar
    mov bl, 0          ; Черный
    mov cl, ' '
    call PutPixel
    ret
ENDP EraseChar

PROC PutPixel
    ; Вход: AL=X, DL=Y, CL=Sym, BL=Color
    push ax bx dx di es
    
    ; Offset = (Y * 80 + X) * 2
    xor dh, dh
    push ax
    mov al, 80
    mul dl             ; AX = Y * 80
    mov di, ax
    pop ax
    
    xor ah, ah
    add di, ax
    add di, di         ; * 2
    
    mov es:[di], cl
    mov es:[di+1], bl
    
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
    
    push bx cx         ; Сохраним счетчики
    
    mov bl, 02h
    mov cl, '0'
    call PutPixel
    
    pop cx bx
    inc bx
    loop DrLoop
    ret
ENDP DrawSnake

PROC CreateFood
    ; Простой рандом (из таймера)
    mov ah, 00h
    int 1Ah
    
    ; X
    mov ax, dx
    xor dx, dx
    mov cx, 76
    div cx
    add dl, 2
    mov [FoodX], dl
    
    ; Y
    mov ax, dx ; берем остаток от X для энтропии
    add ax, [word ptr SnakeX] 
    xor dx, dx
    mov cx, 20
    div cx
    add dl, 2
    mov [FoodY], dl
    
    ; Draw
    mov al, [FoodX]
    mov dl, [FoodY]
    mov bl, 04h        ; Красный
    mov cl, '*'
    call PutPixel
    ret
ENDP CreateFood

; =========================================================
; ДАННЫЕ (В конце для COM файла)
; =========================================================
MsgOver    db 'Game Over!$'
FoodX      db ?
FoodY      db ?
CurrentDir db ?
SnakeLen   db ?
SnakeX     db 100 dup(?)
SnakeY     db 100 dup(?)

END start