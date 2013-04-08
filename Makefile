
ddpg: ddpg.d dunnart.d grammar.d sets.d symbols.d ddlib/lexan.d cli.d Makefile
	dmd ddpg.d dunnart.d grammar.d sets.d symbols.d ddlib/lexan.d cli.d

dunnart.d: ddpg_bespoke dunnart.ddgs
	./ddpg_bespoke -f -v dunnart.ddgs

ddpg_bespoke: ddpg_bespoke.d generated.d grammar.d sets.d symbols.d ddlib/lexan.d cli.d Makefile
	dmd ddpg_bespoke.d generated.d grammar.d sets.d symbols.d ddlib/lexan.d cli.d

generated.d: bespoke Makefile
	./bespoke --force --verbose $@ > bespoke_vo

bespoke: bespoke.d grammar.d sets.d symbols.d ddlib/lexan.d ddlib/templates.d idnumber.d Makefile
	dmd bespoke.d grammar.d sets.d symbols.d ddlib/lexan.d
