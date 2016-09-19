calc: calc.d parser.d
	dmd -I../.. calc.d parser.d ../../../ddlb/lexan.d ../../../ddlb/templates.d

parser.d: parser.ddgs ../../ddpg
	../../ddpg -f --states=parser.states --expect=1 parser.ddgs

test: calc test_data
	./calc test_data
