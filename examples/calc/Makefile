calc: calc.d parser.d
	dmd -I../.. calc.d parser.d ../../ddlib/lexan.d ../../ddlib/templates.d

parser.d: parser.ddgs ../../ddpg
	../../ddpg -f parser.ddgs

test: calc test_data
	./calc test_data
