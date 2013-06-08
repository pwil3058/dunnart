calc: evaluator.d parser.d
	dmd -I../.. evaluator.d parser.d ../../ddlib/lexan.d ../../ddlib/templates.d

parser.d: parser.ddgs ../../ddpg
	../../ddpg -f parser.ddgs
