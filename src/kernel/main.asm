org 0x7C00
bits 16

%define ENDL 0x0D, 0x0A ; endline for line breaking

start:
	jmp main

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

main:
	; setup data segments
	mov ax, 0
	mov ds, ax
	mov es, ax

	; setup stack
	mov ss, ax
	mov sp, 0x7C00 ; stack grows downwards

	; print message
	mov si, msg_hello
	call puts

	hlt

.halt:
	jmp .halt

msg_hello: db "Hello world!", ENDL,  0

times 510-($-$$) db 0
dw 0AA55h
