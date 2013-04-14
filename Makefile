
ddpg: ddpg.d dunnart.d grammar.d sets.d symbols.d ddlib/lexan.d cli.d Makefile
	dmd ddpg.d dunnart.d grammar.d sets.d symbols.d ddlib/lexan.d cli.d

dunnart.d: ddpg_bootstrap dunnart.ddgs
	./ddpg_bootstrap -f dunnart.ddgs

ddpg_bootstrap: ddpg.d bootstrap.d grammar.d sets.d symbols.d ddlib/lexan.d cli.d Makefile
	dmd -ofddpg_bootstrap -version=bootstrap ddpg.d bootstrap.d grammar.d sets.d symbols.d ddlib/lexan.d cli.d
