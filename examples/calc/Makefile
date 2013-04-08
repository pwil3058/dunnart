calc: calc.d parser.d
	dmd -I../.. calc.d parser.d ../../ddlib/lexan.d ../../ddlib/templates.d

parser.d: parser.ddgs
	../../ddpg -f parser.ddgs
