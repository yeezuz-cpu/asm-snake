; snake in assembly (nasm, windows 64 bit)
; nasm -f win64 snake.asm -o snake.o
; gcc snake.o -o snake.exe
default rel
bits 64

W equ 40
H equ 20
ROW equ 43              ; one screen row = 42 chars + newline
GRID equ 946            ; 43 * 22

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

    ; hide the cursor
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

    ; snake starts in the middle going right
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
    ; ---- keys ----
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
    cmp byte [lastx], 1     ; cant turn back on yourself
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
    mov ecx, 0x1B           ; esc
    call GetAsyncKeyState
    test ax, 0x8000
    jnz quit

    ; ---- move ----
    movsx eax, byte [dirx]
    movsx edx, byte [diry]
    mov [lastx], al
    mov [lasty], dl

    lea r8, [snakex]
    lea r9, [snakey]
    movsx ecx, byte [r8]
    add eax, ecx            ; eax = new x
    movsx ecx, byte [r9]
    add edx, ecx            ; edx = new y

    ; hit a wall?
    cmp eax, 0
    jl dead
    cmp eax, W
    jge dead
    cmp edx, 0
    jl dead
    cmp edx, H
    jge dead

    ; did we hit ourselves? (checks every segment, even the tail)
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

    ; ate the food?
    mov r10d, 0
    cmp al, [foodx]
    jne no_food
    cmp dl, [foody]
    jne no_food
    mov r10d, 1
    inc dword [len]
    inc dword [score]
no_food:

    ; move every segment back one spot
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

    ; ---- draw ----
draw:
    lea rdi, [buf]
    mov esi, 0              ; row
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

    ; footer
    lea rsi, [footer]
    mov ecx, FLEN
    rep movsb

    ; score digits
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

    ; food
    movzx eax, byte [foody]
    inc eax
    imul eax, ROW
    movzx edx, byte [foodx]
    add eax, edx
    inc eax
    lea r10, [buf]
    mov byte [r10+rax], '*'

    ; snake body, then the head on top
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

    ; print it
    mov rcx, [hout]
    mov edx, 0
    call SetConsoleCursorPosition
    mov rcx, [hout]
    lea rdx, [buf]
    mov r8d, GRID+FLEN
    lea r9, [rsp+40]
    mov qword [rsp+32], 0
    call WriteConsoleA

    ; get faster the more you eat
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
    mov edx, 22*65536       ; put cursor on the footer line
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
    mov dword [cursor+4], 1     ; show cursor again
    mov rcx, [hout]
    lea rdx, [cursor]
    call SetConsoleCursorInfo
    mov rcx, [hout]
    mov edx, 23*65536
    call SetConsoleCursorPosition
    mov ecx, 0
    call ExitProcess

; pick a random spot for the food
; (doesnt check the snake, so it can show up under it for a moment)
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
