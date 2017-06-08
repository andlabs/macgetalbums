all: macgetalbums.m
	clang -o macgetalbums macgetalbums.m -framework Foundation -g -Wall -Wextra -pedantic -Wno-unused-parameter --std=c99
