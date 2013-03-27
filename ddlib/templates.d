module ddlib.templates;

mixin template DDParserSupport() {
    import ddc = ddlib.components;
    import ddlexan = ddlib.lexan;

    alias ddc.ProductionId DDProduction;
    alias ddc.ParserStateId DDParserState;
    alias ddc.ParseAction DDParseAction;
    alias ddc.ParseActionType DDParseActionType;
    alias ddlexan.TokenSpec DDTokenSpec;
    alias ddlexan.CharLocation DDCharLocation;

    DDParseAction
    ddShift(DDParserState ddState)
    {
        return DDParseAction(DDParseActionType.shift, ddState);
    }
    DDParseAction
    ddReduce(DDProduction ddProduction)
    {
        return DDParseAction(DDParseActionType.reduce, ddProduction);
    }
    DDParseAction
    ddError()
    {
        return DDParseAction(DDParseActionType.error, 0);
    }
    DDParseAction
    ddAccept()
    {
        return DDParseAction(DDParseActionType.accept, 0);
    }

    class DDLexicalAnalyser: ddlexan.LexicalAnalyser {
        this()
        {
            super(ddTokenSpecs, ddSkipRules);
        }
    }
}
