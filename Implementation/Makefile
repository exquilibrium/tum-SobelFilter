.PHONY test: all run

all: O3

#############################################################
# DON'T change the variable names of INCLUDEDIRS and SOURCE
#############################################################
# A list of include directories
INCLUDEDIRS = 
# A list of source files
SOURCE = a_impl.c a_impl.S a_impl_simd.S

# Warning flags
# For more information about gcc warnings: https://embeddedartistry.com/blog/2017/3/7/clang-weverything
# -Wall:		        Print warnings
# -Wextra:		        Enable additional warnings not covered by "-Wall"
# -Wpedantic:	        Reject everything that is not ISO C
# -g					Generates debug information to be used by GDB debugger
WFLAGS = -Wall -Wextra -Wpedantic -D_POSIX_C_SOURCE=199309L 

# Compile without sanitizers and disable optimisation
# $(SOURCE): 	        Input file(s)
# $(INCLUDEDIRS:%=-I%)  Include directories
# -o: 			        Link the resulting object files
# $@.out:	            Built-in variable representing the current target name + file extension .out
# -std=c11              Set C standard
# -O0:			        Do not optimlize the program
# $(WFLAGS)             Warning flags
 
O3: FORCE
	gcc $(SOURCE) $(INCLUDEDIRS:%=-I%) -g -o a_impl.out -std=c11 -O3 -lm $(WFLAGS)

O2: FORCE
	gcc $(SOURCE) $(INCLUDEDIRS:%=-I%) -g -o a_impl.out -std=c11 -O2 -lm $(WFLAGS)

O1: FORCE
	gcc $(SOURCE) $(INCLUDEDIRS:%=-I%) -g -o a_impl.out -std=c11 -O1 -lm $(WFLAGS)

O0: FORCE
	gcc $(SOURCE) $(INCLUDEDIRS:%=-I%) -g -o a_impl.out -std=c11 -O0 -lm $(WFLAGS)

# Execute the compiled programm
run:
	./a_impl.out

clean:
	rm a_impl.out

imageTest:
	gcc imageComp.c  $(INCLUDEDIRS:%=-I%) -g -o imageTest.out -std=c11 -O3 -lm $(WFLAGS)	
# Make sure we allways rebuild
# Required for the tester
FORCE: ;

