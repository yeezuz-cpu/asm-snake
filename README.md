# asm-snake

snake in assembly for the windows console. my first asm project.

controls: WASD or arrows, R to restart, Esc to quit

build (needs nasm and gcc):

    nasm -f win64 snake.asm -o snake.o
    gcc snake.o -o snake.exe
