
ddpg_bespoke: ddpg_bespoke.d generated.d grammar.d sets.d symbols.d ddlib/lexan.d
	dmd ddpg_bespoke.d generated.d grammar.d sets.d symbols.d ddlib/lexan.d

generated.d: bespoke
	./bespoke --force $@

bespoke: bespoke.d grammar.d sets.d symbols.d ddlib/components.d ddlib/lexan.d ddlib/templates.d
	dmd bespoke.d grammar.d sets.d symbols.d ddlib/components.d ddlib/lexan.d
