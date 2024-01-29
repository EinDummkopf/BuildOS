org 0x7C00
bits 16

%define ENDL 0x0D, 0x0A ; endline for line breaking

;
; FAT12 header
;
jmp short start
nop

bdb_oem:	db 'MSWIN4.1' ; 8bytes
bdb_bytes_per_sector:	dw 512
bdb_sectors_per_cluster: 	db 1
bdb_reserved_sectors:	dw 1
bdb_fat_count:	db 2
bdb_dir_entries_count: dw 0E0h
bdb_total_sectors:	dw 2880 ; 2880 * 512 = 1.44MB
bdb_media_descriptor_type:	db 0F0h ; F0 = 3.5 floopy disk
bdb_sectors_per_fat: 	dw 9 ; 9 sectors/fat
bdb_sectors_per_track:	dw 18
bdb_heads:	dw 2
bdb_hidden_sectors:	dd 0
bdb_large_sector_count:	dd 0

; extended boot record
ebr_drive_number:	db 0 ; 0x0 = floppy, 0x80 = hdd
					db 0 ; reserved
ebr_signature:	db 29h
ebr_volume_id:	db 12h, 34h, 56h, 78h ; serial number, value doesn't matter
ebr_volume_label:	db 'OPERETING!!'
ebr_system_id:	db 'FAT12   ' ; 8 bytes

;
; Code goes here
;


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

;
; Disk routines
;

lba_to_chs:
	push ax
	push dx

	xor dx, dx ; dx = 0
	div word [bdb_sectors_per_track] ; ax = LBA / SectorsPerTrack
									 ; dx = LBA % SectorsPerTrack
	inc dx ; dx = (LBA % SectorsPerTrack + 1) = sector
	mov cx, dx ; cx = sector

	xor dx, dx
	div word [bdb_heads] ; ax = (LBA / SectorsPerTrack) / Heads = cylinder
						 ; dx = (LBA / SectorsPerTrack) % Heads = head
	mov dh, dl ; dh = head
	mov ch, al ; ch = Cylinder ( lower & 8bit)
	shl ah, 6
	or cl, ah ; put upper 2 bits of cylinder in CL

	pop ax
	mov dl, al ; restore DL
	pop ax
	ret

msg_hello: db "Hello world!", ENDL,  0

times 510-($-$$) db 0
dw 0AA55h
