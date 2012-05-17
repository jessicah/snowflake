
# gist: https://gist.github.com/d86e3b8c55c375655b73

.global __entrypoint

.set ALIGN,    1 << 0
.set MEMINFO,  1 << 1
.set FLAGS,    ALIGN | MEMINFO
.set MAGIC,    0x1BADB002
.set PADDING,  0
.set CHECKSUM, -(MAGIC + FLAGS)

.section .mb_header
.align 4
.long MAGIC
.long FLAGS
.long CHECKSUM
.long PADDING

.section .text
.set STACKSIZE, 0x40000
.comm stack, STACKSIZE, 32

__entrypoint: .code32
	# set up stack, push multiboot arguments
	mov $(stack + STACKSIZE), %esp
	push %eax
	push %ebx

	# steps to do according to amd64 documentation:
	# 1. enable physical address extension (PAE)
	mov %cr4, %eax
	bts $5, %eax
	mov %eax, %cr4
	# 2. load CR3 with physical address of the level-4 page map table
	#    identity map 0-4GB
	#    map 0xFFFF123400000000+4GB to 0-4GB
	#    both map same region; GC will only see pointers in second region
	# 3. enable long mode
	mov $0xC0000080, %ecx
	rdmsr
	bts $8, %eax
	wrmsr
	# 4. enable paging
	mov %cr0, %eax
	bts $31, %eax
	mov %eax, %cr0
	# 5. branch to 64-bit code
	# AMD sample loads %rsp here...
	# 6. load GDT/IDT
	lgdt (gdt_ptr)
	ljmp $0x08, $new_gdt
.align 8
new_gdt: .code64
	# do I need this part?
	movq $1f, %rax
	jmp *%rax
1:
	xor %rax, %rax
	mov %eax, %ds
	mov %eax, %ss
	mov %eax, %es
	mov %eax, %fs
	mov %eax, %gs

	# 7. running in 64-bit mode; call __startup
	xor %rbp, %rbp

	movl $33, %eax
	movl %eax, %cr0
	fninit
	call __startup
5:
	hlt
	jmp 5b

.section .data

gdt:
	# null descriptor -- used for DS/SS/etc
	.word 0
	.word 0
	.byte 0
	.byte 0
	.byte 0
	.byte 0
	# ring 0 kernel code segment descriptor -- code64 (0x08)
	.quad 0x00209A0000000000
	#.word 0xFFFF
	#.word 0
	#.byte 0
	#.byte 0x9A
	#.byte 0xCF
	#.byte 0
gdt_end:

gdt_ptr:
	.word gdt_end - gdt - 1
	.long gdt
