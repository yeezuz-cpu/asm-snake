; snake in asm. first time doing this so dont judge
; nasm -f win64 snake.asm -o snake.o
; gcc snake.o -o snake.exe
default rel
bits 64

W equ 40
H equ 20
ROW equ 43              ; 42 chars + newline
GRID equ 946            ; 43 * 22, dont ask me to change the board size

extern GetStdHandle, WriteConsoleA, SetConsoleCursorPosition, SetConsoleCursorInfo
extern GetAsyncKeyState, Sleep, GetTickCount, ExitProcess
global main

section .data
footer db "Score: 000  WASD/arrows to move, Esc to quit", 10
FLEN equ $-footer
msg db "GAME OVER! R = restart, Esc = quit      ", 10
MLEN equ $-msg
cursor dd 1, 0

section .bss
hout resq 1
buf resb 1000
snakex resb 1000
snakey resb 1000
len resd 1
score resd 1
seed resd 1
dirx resb 1
diry resb 1
lastx resb 1
lasty resb 1
foodx resb 1
foody resb 1

section .text
main:
    sub rsp, 56

    mov ecx, -11
    call GetStdHandle
    mov [hout], rax

    ; hide the blinking cursor it was annoying
    mov rcx, [hout]
    lea rdx, [cursor]
    call SetConsoleCursorInfo

    call GetTickCount
    mov [seed], eax

start:
    mov dword [len], 3
    mov dword [score], 0
    mov byte [dirx], 1
    mov byte [diry], 0
    mov byte [lastx], 1
    mov byte [lasty], 0

    ; snake starts in the middle, 3 long
    lea r8, [snakex]
    lea r9, [snakey]
    mov byte [r8], 20
    mov byte [r8+1], 19
    mov byte [r8+2], 18
    mov byte [r9], 10
    mov byte [r9+1], 10
    mov byte [r9+2], 10

    call newfood

loop_start:
    ; arrows AND wasd. yes its copy paste 8 times, no i dont know a better way
    ; left
    mov ecx, 0x25
    call GetAsyncKeyState
    test ax, 0x8000
    jnz go_left
    mov ecx, 0x41
    call GetAsyncKeyState
    test ax, 0x8000
    jnz go_left
    ; right
    mov ecx, 0x27
    call GetAsyncKeyState
    test ax, 0x8000
    jnz go_right
    mov ecx, 0x44
    call GetAsyncKeyState
    test ax, 0x8000
    jnz go_right
    ; up
    mov ecx, 0x26
    call GetAsyncKeyState
    test ax, 0x8000
    jnz go_up
    mov ecx, 0x57
    call GetAsyncKeyState
    test ax, 0x8000
    jnz go_up
    ; down
    mov ecx, 0x28
    call GetAsyncKeyState
    test ax, 0x8000
    jnz go_down
    mov ecx, 0x53
    call GetAsyncKeyState
    test ax, 0x8000
    jnz go_down
    jmp keys_done

go_left:
    cmp byte [lastx], 1     ; no 180 turns or u die instantly
    je keys_done
    mov byte [dirx], -1
    mov byte [diry], 0
    jmp keys_done
go_right:
    cmp byte [lastx], -1
    je keys_done
    mov byte [dirx], 1
    mov byte [diry], 0
    jmp keys_done
go_up:
    cmp byte [lasty], 1
    je keys_done
    mov byte [dirx], 0
    mov byte [diry], -1
    jmp keys_done
go_down:
    cmp byte [lasty], -1
    je keys_done
    mov byte [dirx], 0
    mov byte [diry], 1

keys_done:
    mov ecx, 0x1B           ; esc key
    call GetAsyncKeyState
    test ax, 0x8000
    jnz quit

    ; moving the head
    movsx eax, byte [dirx]
    movsx edx, byte [diry]
    mov [lastx], al
    mov [lasty], dl

    lea r8, [snakex]
    lea r9, [snakey]
    movsx ecx, byte [r8]
    add eax, ecx            ; new x
    movsx ecx, byte [r9]
    add edx, ecx            ; new y

    ; wall = dead
    cmp eax, 0
    jl dead
    cmp eax, W
    jge dead
    cmp edx, 0
    jl dead
    cmp edx, H
    jge dead

    ; ate yourself? checks the tail too, whatever
    mov ecx, 0
self_check:
    cmp ecx, [len]
    jge self_ok
    cmp al, [r8+rcx]
    jne self_next
    cmp dl, [r9+rcx]
    je dead
self_next:
    inc ecx
    jmp self_check
self_ok:

    ; food time
    mov r10d, 0
    cmp al, [foodx]
    jne no_food
    cmp dl, [foody]
    jne no_food
    mov r10d, 1
    inc dword [len]
    inc dword [score]
no_food:

    ; every segment copies the one in front of it, snake brain
    mov ecx, [len]
    dec ecx
shift:
    cmp ecx, 0
    jle shift_done
    mov r11b, [r8+rcx-1]
    mov [r8+rcx], r11b
    mov r11b, [r9+rcx-1]
    mov [r9+rcx], r11b
    dec ecx
    jmp shift
shift_done:
    mov [r8], al
    mov [r9], dl

    cmp r10d, 1
    jne draw
    call newfood

draw:
    lea rdi, [buf]
    mov esi, 0              ; row (esi because it was free)
draw_row:
    mov edx, 0              ; column
draw_col:
    mov al, ' '
    cmp esi, 0
    je is_wall
    cmp esi, H+1
    je is_wall
    cmp edx, 0
    je is_wall
    cmp edx, W+1
    je is_wall
    jmp put_char
is_wall:
    mov al, '#'
put_char:
    mov [rdi], al
    inc rdi
    inc edx
    cmp edx, W+2
    jl draw_col
    mov byte [rdi], 10
    inc rdi
    inc esi
    cmp esi, H+2
    jl draw_row

    ; text at the bottom
    lea rsi, [footer]
    mov ecx, FLEN
    rep movsb

    ; score digits. why do i do it this way? i dont fucking know
    mov eax, [score]
    xor edx, edx
    mov ecx, 100
    div ecx
    add al, '0'
    mov [buf+GRID+7], al
    mov eax, edx
    xor edx, edx
    mov ecx, 10
    div ecx
    add al, '0'
    add dl, '0'
    mov [buf+GRID+8], al
    mov [buf+GRID+9], dl

    ; food goes in the buffer
    movzx eax, byte [foody]
    inc eax
    imul eax, ROW
    movzx edx, byte [foodx]
    add eax, edx
    inc eax
    lea r10, [buf]
    mov byte [r10+rax], '*'

    ; body first then head on top so the head doesnt get overwritten
    lea r8, [snakex]
    lea r9, [snakey]
    mov ecx, [len]
    dec ecx
draw_snake:
    cmp ecx, 0
    jl draw_done
    movzx eax, byte [r9+rcx]
    inc eax
    imul eax, ROW
    movzx edx, byte [r8+rcx]
    add eax, edx
    inc eax
    mov byte [r10+rax], 'o'
    dec ecx
    jmp draw_snake
draw_done:
    movzx eax, byte [snakey]
    inc eax
    imul eax, ROW
    movzx edx, byte [snakex]
    add eax, edx
    inc eax
    mov byte [r10+rax], '@'

    ; throw it on the screen
    mov rcx, [hout]
    mov edx, 0
    call SetConsoleCursorPosition
    mov rcx, [hout]
    lea rdx, [buf]
    mov r8d, GRID+FLEN
    lea r9, [rsp+40]
    mov qword [rsp+32], 0
    call WriteConsoleA

    ; faster the more u eat. magic numbers, they felt right
    mov ecx, [score]
    cmp ecx, 30
    jle speed
    mov ecx, 30
speed:
    imul ecx, 2
    mov eax, 130
    sub eax, ecx
    mov ecx, eax
    call Sleep

    jmp loop_start

dead:
    mov rcx, [hout]
    mov edx, 22*65536       ; footer line
    call SetConsoleCursorPosition
    mov rcx, [hout]
    lea rdx, [msg]
    mov r8d, MLEN
    lea r9, [rsp+40]
    mov qword [rsp+32], 0
    call WriteConsoleA
wait_key:
    mov ecx, 0x52           ; r
    call GetAsyncKeyState
    test ax, 0x8000
    jnz start
    mov ecx, 0x1B
    call GetAsyncKeyState
    test ax, 0x8000
    jnz quit
    mov ecx, 20
    call Sleep
    jmp wait_key

quit:
    mov dword [cursor+4], 1     ; give the cursor back
    mov rcx, [hout]
    lea rdx, [cursor]
    call SetConsoleCursorInfo
    mov rcx, [hout]
    mov edx, 23*65536
    call SetConsoleCursorPosition
    mov ecx, 0
    call ExitProcess

; random food spot
; doesnt check if the snake is there. sometimes the food is inside you. skill issue
newfood:
    imul eax, [seed], 1103515245
    add eax, 12345
    mov [seed], eax
    shr eax, 16
    xor edx, edx
    mov ecx, W
    div ecx
    mov [foodx], dl

    imul eax, [seed], 1103515245
    add eax, 12345
    mov [seed], eax
    shr eax, 16
    xor edx, edx
    mov ecx, H
    div ecx
    mov [foody], dl
    ret
