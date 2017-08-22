#!/bin/bash

fourthGen() {
	awk '{
		x = $NF
		gsub(/:/, "", x)
		print $0 "\t" x
	}'
}
fourthStrip() {
	cut -d$'\t' -f-4
}

fourthFirst=cat
fourthSort=
fourthLast=cat
[ z$1 = z-l ] && {
	fourthFirst=fourthGen
	fourthSort=-k5,5n
	fourthLast=fourthStrip
}

$fourthFirst |
	sort -t$'\t' $fourthSort -k1,1n -k2,2 -k3,3 |
	$fourthLast |
	column -t -s$'\t'
