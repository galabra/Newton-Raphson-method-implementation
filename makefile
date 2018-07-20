root: root.o
	gcc -g -Wall -o root root.o

root.o: root.s
	nasm -g -f elf64 -w+all -o root.o root.s

	
#tell make that "clean" is not a file name!
.PHONY: clean

#Clean the build directory
clean: 
	rm -f *.o root