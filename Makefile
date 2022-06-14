FILES=$(notdir $(wildcard ./src/*.asm))
OBJS=$(addprefix ./obj/, $(FILES:.asm=.o))
EXE:=main
RM:=rm -f

$(EXE): $(OBJS)
	ld -o $@ $^

./obj/%.o: ./src/%.asm
	nasm -f elf64 $< -o $@ -g -F dwarf

.PHONY: check clean
check: $(EXE)
	./$<

clean:
	$(RM) $(EXE) $(OBJS)

