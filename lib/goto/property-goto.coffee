AbstractGoto = require './abstract-goto'
{TextEditor} = require 'atom'

module.exports =
class GotoProperty extends AbstractGoto

    hoverEventSelectors: '.property'
    clickEventSelectors: '.property'
    gotoRegex: /^(\$\w+)?((->|::)\w+)+/

    ###*
     * Goto the property from the term given.
     * @param  {TextEditor} editor  TextEditor to search for namespace of term.
     * @param  {string}     term    Term to search for.
    ###
    gotoFromWord: (editor, term) ->
        bufferPosition = editor.getCursorBufferPosition()

        calledClassInfo = @getCalledClassInfo(editor, term, bufferPosition)
        calledClass = calledClassInfo.calledClass
        splitter = calledClassInfo.splitter

        currentClass = @parser.getCurrentClass(editor, bufferPosition)

        termParts = term.split(splitter)
        term = termParts.pop()
        if currentClass == calledClass && @jumpTo(editor, term)
            @manager.addBackTrack(editor.getPath(), editor.getCursorBufferPosition())
            return

        value = @getPropertyForTerm(editor, term, bufferPosition, calledClassInfo)

        parentClass = value.declaringClass

        proxy = require '../services/php-proxy.coffee'
        classMap = proxy.autoloadClassMap()

        atom.workspace.open(classMap[parentClass], {
            searchAllPanes: true
        })
        @manager.addBackTrack(editor.getPath(), editor.getCursorBufferPosition())
        @jumpWord = term

    ###*
     * Retrieves a tooltip for the word given.
     * @param  {TextEditor} editor         TextEditor to search for namespace of term.
     * @param  {string}     term           Term to search for.
     * @param  {Point}      bufferPosition The cursor location the term is at.
    ###
    getTooltipForWord: (editor, term, bufferPosition) ->
        value = @getPropertyForTerm(editor, term, bufferPosition)

        # Create a useful description to show in the tooltip.
        returnType = if value.args.return then value.args.return else 'mixed'

        description = (if value.isPublic then 'public' else ' protected|private') + ' ' + returnType + ' $' + term;

        description += "<br/><br/>"

        if value.args.descriptions.short
            description += value.args.descriptions.short

        else
            description += '(No documentation available)'

        return description

    ###*
     * Retrieves the called class and the splitter used.
     * @param  {TextEditor} editor         TextEditor to search for namespace of term.
     * @param  {string}     term           Term to search for.
     * @param  {Point}      bufferPosition The cursor location the term is at.
    ###
    getCalledClassInfo: (editor, term, bufferPosition) ->
        proxy = require '../services/php-proxy.coffee'
        fullCall = @parser.getStackClasses(editor, bufferPosition)

        if fullCall.length == 0 or !term
          return

        calledClass = ''
        splitter = '->'
        if fullCall.length > 1
            calledClass = @parser.parseElements(editor, bufferPosition, fullCall)
        else
            parts = fullCall[0].trim().split('::')
            splitter = '::'
            if parts[0] == 'parent'
                calledClass = @parser.getParentClass(editor)
            else
                calledClass = @parser.findUseForClass(editor, parts[0])

        return {
            calledClass : calledClass,
            splitter    : splitter
        }

    ###*
     * Retrieves information about the property described by the specified term.
     * @param  {TextEditor} editor          TextEditor to search for namespace of term.
     * @param  {string}     term            Term to search for.
     * @param  {Point}      bufferPosition  The cursor location the term is at.
     * @param  {Object}     calledClassInfo Information about the called class (optional).
    ###
    getPropertyForTerm: (editor, term, bufferPosition, calledClassInfo) ->
        if not calledClassInfo
            calledClassInfo = @getCalledClassInfo(editor, term, bufferPosition)

        calledClass = calledClassInfo.calledClass

        proxy = require '../services/php-proxy.coffee'
        methodsAndProperties = proxy.methods(calledClass)
        if not methodsAndProperties.names?
            return

        if methodsAndProperties.names.indexOf(term) == -1
            return
        value = methodsAndProperties.values[term]

        if value instanceof Array
            for val in value
                if !val.isMethod
                    value = val
                    break

        return value

    ###*
     * Gets the regex used when looking for a word within the editor
     * @param  {string} term Term being search.
     * @return {regex}       Regex to be used.
    ###
    getJumpToRegex: (term) ->
        return ///(protected|public|private|static)\ +\$#{term}///i
