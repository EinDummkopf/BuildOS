org 0x0
bits 16

%define ENDL 0x0D, 0x0A ; endline for line breaking

start:
	; print message
	mov si, msg_hello
	call puts

.halt:
	cli
	hlt

puts:
	push si
	push ax

.loop:
	lodsb ; load next charactor in al
	or al, al ; verify if next charactor is null?
	jz .done

	mov ah, 0x0E
	mov bh, 0
	int 0x10
	
	jmp .loop

.done:
	pop ax
	pop si
	ret

msg_hello: db "Hello from KERNEL!", ENDL,  0