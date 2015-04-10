[BITS 32]

org 0

section .text

id: dw 0xb800
size: dw 2
dd print_char 
dd move_cursor
boot:
	add esp, 4
	pop ebp
	ret
print_char:
	push ebx

	mov byte al, [ebp + 8]
	cmp byte al, 10
	jne .not_nl
	.new_line:
		mov ebx, [ebp - 4]
		mov word ax, [ebx + index]
		push ecx
		push edx
		xor dx, dx
		mov cx, 80
		div cx
		inc ax
		mul cx
		mov ebx, [ebp - 4]
		mov [ebx + index], ax
		pop edx
		pop ecx
		jmp short .end
	.not_nl:
		mov ebx, [ebp - 4]
		mov word bx, [ebx + index]
		and ebx, 0xffff
		mov ah, 0x17
		mov word [0xb8000 + ebx*2], ax
		
		mov ebx, [ebp - 4]
		inc word [ebx + index]

	.end:
		pop ebx
		add esp, 4
		pop ebp
	
	ret
move_cursor:
	push ebx

	mov dword eax, [ebp + 8]
	mov ebx, [ebp - 4]
	mov word [ebx + index], ax

	pop ebx
	add esp, 4
	pop ebp
	ret
global_variables:
	index dw 0
