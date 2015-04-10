[BITS 32]

org 0x100000
MBALIGN     equ  1<<0
MEMINFO     equ  1<<1
MKLUDGE     equ  1<<16
FLAGS       equ  MBALIGN | MEMINFO | MKLUDGE
MAGIC       equ  0x1BADB002
CHECKSUM    equ -(MAGIC + FLAGS)

section .text

multiboot:
align 4
	dd MAGIC
	dd FLAGS
	dd CHECKSUM

aout_k:
	dd multiboot
	dd multiboot
	dd _bss
	dd _end
	dd _start

%define BOS 0x100000
;-----------------------------
GDT:
GDT_0:
	dq 0
GDT_1:
	dw 0xffff ;limit 0:15
	dw 0x0000 ;base  0:15
	db 0x00   ;base  16:23
	db 0x9a   ;access
	db 0xcf   ;flag + limit 16:19
	db 0x00   ;base  24:31
GDT_2:
	dw 0xffff ;limit 0:15
	dw 0x0000 ;base  0:15
	db 0x00   ;base  16:23
	db 0x92   ;access
	db 0xcf   ;flag + limit 16:19
	db 0x00   ;base  24:31
IDT:
	times 64 dq ((BOS - $$ + do_nothing) >> 16) << 48 | 0x8e<< 40 | 0x8<<16 | ((BOS - $$ + do_nothing) & 0xffff)
GDTR:
	dw 0x17
	dd GDT
IDTR:
	dw 0x1ff
	dd IDT
;-----------------------------------
_global:
	color db 0x17
	module_list dd 0
;------------------------------------
do_nothing:
	iret
;--------------------------------
load_module:
	push ebp
	mov ebp, esp
	sub esp, 4
	mov eax, [edx]
	push edx
	mov edx, eax
	mov word ax, [eax]
	and eax, 0xffff
	mov [module_list + eax*4], edx
	xor eax, eax
	mov word ax, [edx + 2]
	lea eax, [eax*4 + 4]
	add eax, edx
	pop edx
	jmp eax

;------------------------------------------
run_module:
	push ebp
	mov ebp, esp
	sub esp, 4
	push ebx
	mov ebx, eax
	shr eax, 16
	push eax
	mov eax, [module_list + eax*4]
	mov [esp + 8], eax
	and ebx, 0xffff
	lea eax, [eax + ebx*4 + 4]
	mov eax, [eax]
	pop ebx
	add eax, [module_list + ebx*4]
	pop ebx
	jmp eax
;--------------------------------------------
_start:
above_MB:
	mov ecx, [ebx + 44]
	add ecx, [ebx + 48]
	mov edx, [ebx + 48]
	jmp .above_1_MB
	.read_next:
		add edx, [edx - 4]
		add edx, 4
	.above_1_MB:
		cmp dword [edx], 0x10000
		jb .read_next
		mov eax, edx
allocate_stack:
	jmp .check_memory_table
	.read_next:
		add edx, [edx - 4]
		add edx, 4
	.check_memory_table:
		test dword [edx + 16], 0x1
		jz .read_next
		cmp dword [edx + 12], 1
		jae .found
		cmp dword [edx + 8], 65536
		jna .read_next
	.found:
		sub dword [edx + 8], 65536
		jnc .else
		sub dword [edx + 12], 1
	.else:
		mov esp, [edx]
		add esp, [edx + 8]
		add esp, 65536
allocate_module_table:
	mov edx, eax
	jmp .check_memory_table
	.read_next:
		add edx, [edx - 4]
		add edx, 4
	.check_memory_table:
		test dword [edx + 16], 0x1
		jz .read_next
		cmp dword [edx + 12], 1
		jae .found
		cmp dword [edx + 8], 65536*4
		jna .read_next
	.found:
		sub dword [edx + 8], 65536*4
		jnc .else
		sub dword [edx + 12], 1
	.else:
		mov eax, [edx]
		add eax, [edx + 8]
		mov dword [module_list], edx
minimum_GDT_IDT_setup:
	lgdt [GDTR]
	lidt [IDTR]
	jmp 0x08:.reload
	.reload:
		mov ax, 0x10
		mov ds, ax
		mov es, ax
		mov fs, ax
		mov gs, ax
		mov ss, ax

PIC_remap:
	mov al, 0x11
	out byte 0x20, al ;start init sequence
	out byte 0xa0, al
	
	mov al, 0x20

	out byte 0x21, al ;point to offset
	mov al, 0x28
	out byte 0xa1, al

	mov al, 0x4
	out byte 0x21, al ;tell cascade identity
	mov al, 0x2
	out byte 0xa1, al
	
	mov al, 0x01
	out byte 0x21, al
	out byte 0xa1, al

PIC_mask:
	mov al, 0xfd
	out 0x21, al
	mov al, 0xff
	out 0xa1, al

load_modules:
	mov ecx, [ebx + 20]
	mov edx, [ebx + 24]
	.loop:
		jecxz finish
		call load_module
		add edx, 16
		dec ecx
		jmp .loop
finish:
	sti
temp:
	call print_mem_table
_stop:
	hlt
	jmp _stop
hi: db "Hello world!", 0
tempbuff: resb 50
;--------------------------------------------
;; ecx = count
;; edx = buffer
pad_space:
	jecxz .end
	mov byte [edx + ecx], ' '
	dec ecx
	jmp pad_space

	.end:
		ret
;; eax = number
;; edx = buffer
show_int:
	push ecx
	push edx
	mov edx, .buf
	.loop:
		push edx
		xchg ecx, edx
		xor edx, edx
		mov ecx, 10
		div ecx
		add edx, 0x30
		xchg edx, ecx
		pop edx
		mov byte [edx], cl
		inc edx
		or eax, eax
		jnz .loop

	sub edx, .buf
	mov ecx, edx
	mov edx, [esp]
	.lo1p:
		jecxz .end
		mov byte al, [.buf + ecx - 1]
		mov byte [edx], al
		inc edx
		dec ecx
		jmp .lo1p	
	
	.end:
		pop edx
		pop ecx
		ret

	.buf: resb 10
;----------------
show_hex_2:
	push ecx
	push edx
	mov ecx, 8
	.loop:
		push ecx
		mov cl, al
		and cl, 0xf
		cmp cl, 0xa
		jb .else
		add cl, 7	
	.else:
		add cl, 0x30
		mov [.temp], eax
		mov al, cl
		pop ecx
		mov byte [edx + ecx + 1], al
		mov eax, [.temp]

		shr eax, 4
		dec ecx
		jnz .loop
	
	.end:
		mov byte [edx+1], 'x'
		mov byte [edx], '0'
		
		pop edx
		pop ecx
		ret
	.temp dd 0
;------------------------
show_hex:
	push ecx
	push edx
	mov edx, .buf
	.loop:
		mov cl, al
		and cl, 0xf
		cmp cl, 0xa
		jb .else
		add cl, 7	
	.else:
		add cl, 0x30
		mov byte [edx], cl
		inc edx
		shr eax, 4
		jnz .loop
	
	mov byte [edx], 'x'
	inc edx
	mov byte [edx], '0'
	inc edx
	sub edx, .buf
	mov ecx, edx
	mov edx, [esp]
	.lo1p:
		jecxz .end
		mov byte al, [.buf + ecx - 1]
		mov byte [edx], al
		inc edx
		dec ecx
		jmp .lo1p	
	
	.end:
		pop edx
		pop ecx
		ret

	.buf: resb 10
;---------------------
print_mem_table:
	push ecx
	push edx
	mov ecx, [ebx + 44]
	add ecx, [ebx + 48]
	mov edx, [ebx + 48]
	
	.loop:
		cmp edx, ecx
		jnb .end

		push edx
		push ecx
		mov edx, .buf0
		mov ecx, 10
		call pad_space
		mov edx, .buf1
		mov ecx, 10
		call pad_space
		pop ecx
		pop edx		

		mov eax, [edx]
		push edx
		mov edx, .buf0
		call show_hex_2
		pop edx
	
		mov eax, [edx + 8]	
		push edx
		mov edx, .buf1
		call show_int
		pop edx

		push edx
		mov edx, .mes0
		call print_string
		pop edx
		
		push edx
		cmp dword [edx + 16], 1
		jne .else
		mov edx, .free
		jmp .end_1
		.else:
		mov edx, .res
		.end_1
		call print_string
		pop edx

		add edx, [edx - 4]
		add edx, 4
		jmp .loop
	.end:
		pop edx
		pop ecx
		ret
	.mes0: db "BASE "
	.buf0: times 11 db ' '
	.mes1: db "SIZE "
	.buf1: times 11 db ' '
	 db 0
	.res: db "RESERVED", 10, 0
	.free: db "FREE", 10, 0
;---------------------------
; edx = string
print_string:
	push edx
	
	.loop:
		cmp byte [edx], 0
		je .end
		
		mov eax, 0xb8000000
		push dword [edx]
		call run_module
		pop eax
		inc edx
		jmp .loop
	.end:
		pop edx
		ret
_bss:
_end:
