
ddpg_bespoke: ddpg_bespoke.d generated.d grammar.d sets.d symbols.d ddlib/lexan.d Makefile
	dmd ddpg_bespoke.d generated.d grammar.d sets.d symbols.d ddlib/lexan.d

generated.d: bespoke Makefile
	./bespoke --force --verbose $@ > bespoke_vo

bespoke: bespoke.d grammar.d sets.d symbols.d ddlib/components.d ddlib/lexan.d ddlib/templates.d idnumber.d Makefile
	dmd bespoke.d grammar.d sets.d symbols.d ddlib/components.d ddlib/lexan.d
