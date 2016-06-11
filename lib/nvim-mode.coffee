
{Disposable, CompositeDisposable} = require 'atom'

NvimState = require './nvim-state'

module.exports =

  activate: ->

    console.log 'We have started development'

    @disposables = new CompositeDisposable

    @disposables.add atom.commands.add 'atom-workspace',
      'nvim-mode:test': => @test()

    @disposables.add atom.workspace.observeTextEditors (editor) ->

      console.log 'uri:',editor.getURI()
      editorView = atom.views.getView(editor)

      if editorView
        console.log 'view:',editorView
        editorView.classList.add('nvim-mode')
        editorView.nvimState = new NvimState(editorView)


  deactivate: ->

    atom.workspaceView?.eachEditorView (editorView) ->
      editorView.off('.nvim-mode')

    @disposables.dispose()

  test: ->
    console.log 'Neovim Mode Test Initialized...'

    console.log 'All tests passed'
