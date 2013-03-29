
generated.d: bespoke
	./bespoke > $@

bespoke: bespoke.d grammar.d sets.d symbols.d ddlib/components.d ddlib/lexan.d
	dmd bespoke.d grammar.d sets.d symbols.d ddlib/components.d ddlib/lexan.d
