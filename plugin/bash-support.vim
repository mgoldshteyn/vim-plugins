"===============================================================================
"
"          File:  bash-support.vim
"
"   Description:  Bash support
"
"                  Write Bash scripts by inserting comments, statements,
"                  variables and builtins.
"
"   VIM Version:  7.0+
"        Author:  Wolfgang Mehner <wolfgang-mehner@web.de>
"                 Fritz Mehner <mehner.fritz@web.de>
"       Version:  see g:BASH_Version below
"       Created:  26.02.2001
"      Revision:  28.09.2017
"       License:  Copyright (c) 2001-2015, Dr. Fritz Mehner
"                 Copyright (c) 2016-2017, Wolfgang Mehner
"                 This program is free software; you can redistribute it and/or
"                 modify it under the terms of the GNU General Public License as
"                 published by the Free Software Foundation, version 2 of the
"                 License.
"                 This program is distributed in the hope that it will be
"                 useful, but WITHOUT ANY WARRANTY; without even the implied
"                 warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
"                 PURPOSE.
"                 See the GNU General Public License version 2 for more details.
"===============================================================================

"-------------------------------------------------------------------------------
" === Basic checks ===   {{{1
"-------------------------------------------------------------------------------

" need at least 7.0
if v:version < 700
	echohl WarningMsg
	echo 'The plugin bash-support.vim needs Vim version >= 7.'
	echohl None
	finish
endif

" prevent duplicate loading
" need compatible
if exists("g:BASH_Version") || &cp
	finish
endif

let g:BASH_Version= "4.4pre"                  " version number of this script; do not change

"-------------------------------------------------------------------------------
" === Auxiliary functions ===   {{{1
"-------------------------------------------------------------------------------

"-------------------------------------------------------------------------------
" s:ApplyDefaultSetting : Write default setting to a global variable.   {{{2
"
" Parameters:
"   varname - name of the variable (string)
"   value   - default value (string)
" Returns:
"   -
"
" If g:<varname> does not exists, assign:
"   g:<varname> = value
"-------------------------------------------------------------------------------

function! s:ApplyDefaultSetting ( varname, value )
	if ! exists ( 'g:'.a:varname )
		let { 'g:'.a:varname } = a:value
	endif
endfunction    " ----------  end of function s:ApplyDefaultSetting  ----------

"-------------------------------------------------------------------------------
" s:ErrorMsg : Print an error message.   {{{2
"
" Parameters:
"   line1 - a line (string)
"   line2 - a line (string)
"   ...   - ...
" Returns:
"   -
"-------------------------------------------------------------------------------

function! s:ErrorMsg ( ... )
	echohl WarningMsg
	for line in a:000
		echomsg line
	endfor
	echohl None
endfunction    " ----------  end of function s:ErrorMsg  ----------

"-------------------------------------------------------------------------------
" s:GetGlobalSetting : Get a setting from a global variable.   {{{2
"
" Parameters:
"   varname - name of the variable (string)
"   glbname - name of the global variable (string, optional)
" Returns:
"   -
"
" If 'glbname' is given, it is used as the name of the global variable.
" Otherwise the global variable will also be named 'varname'.
"
" If g:<glbname> exists, assign:
"   s:<varname> = g:<glbname>
"-------------------------------------------------------------------------------

function! s:GetGlobalSetting ( varname, ... )
	let lname = a:varname
	let gname = a:0 >= 1 ? a:1 : lname
	if exists ( 'g:'.gname )
		let { 's:'.lname } = { 'g:'.gname }
	endif
endfunction    " ----------  end of function s:GetGlobalSetting  ----------

"-------------------------------------------------------------------------------
" s:ImportantMsg : Print an important message.   {{{2
"
" Parameters:
"   line1 - a line (string)
"   line2 - a line (string)
"   ...   - ...
" Returns:
"   -
"-------------------------------------------------------------------------------

function! s:ImportantMsg ( ... )
	echohl Search
	echo join ( a:000, "\n" )
	echohl None
endfunction    " ----------  end of function s:ImportantMsg  ----------

"-------------------------------------------------------------------------------
" s:Redraw : Redraw depending on whether a GUI is running.   {{{2
"
" Example:
"   call s:Redraw ( 'r!', '' )
" Clear the screen and redraw in a terminal, do nothing when a GUI is running.
"
" Parameters:
"   cmd_term - redraw command in terminal mode (string)
"   cmd_gui -  redraw command in GUI mode (string)
" Returns:
"   -
"-------------------------------------------------------------------------------

function! s:Redraw ( cmd_term, cmd_gui )
	if has('gui_running')
		let cmd = a:cmd_gui
	else
		let cmd = a:cmd_term
	endif

	let cmd = substitute ( cmd, 'r\%[edraw]', 'redraw', '' )
	if cmd != ''
		silent exe cmd
	endif
endfunction    " ----------  end of function s:Redraw  ----------

"-------------------------------------------------------------------------------
" s:ShellParseArgs : Turn cmd.-line arguments into a list.   {{{2
"
" Parameters:
"   line - the command-line arguments to parse (string)
" Returns:
"   list - the arguments as a list (list)
"-------------------------------------------------------------------------------

function! s:ShellParseArgs ( line )

	let list = []
	let curr = ''

	let line = a:line

	while line != ''

		if match ( line, '^\s' ) != -1
			" non-escaped space -> finishes current argument
			let line = matchstr ( line, '^\s\+\zs.*' )
			if curr != ''
				call add ( list, curr )
				let curr = ''
			endif
		elseif match ( line, "^'" ) != -1
			" start of a single-quoted string, parse past next single quote
			let mlist = matchlist ( line, "^'\\([^']*\\)'\\(.*\\)" )
			if empty ( mlist )
				throw "ShellParseArgs:Syntax:no matching quote '"
			endif
			let curr .= mlist[1]
			let line  = mlist[2]
		elseif match ( line, '^"' ) != -1
			" start of a double-quoted string, parse past next double quote
			let mlist = matchlist ( line, '^"\(\%([^\"]\|\\.\)*\)"\(.*\)' )
			if empty ( mlist )
				throw 'ShellParseArgs:Syntax:no matching quote "'
			endif
			let curr .= substitute ( mlist[1], '\\\([\"]\)', '\1', 'g' )
			let line  = mlist[2]
		elseif match ( line, '^\\' ) != -1
			" escape sequence outside of a string, parse one additional character
			let mlist = matchlist ( line, '^\\\(.\)\(.*\)' )
			if empty ( mlist )
				throw 'ShellParseArgs:Syntax:single backspace \'
			endif
			let curr .= mlist[1]
			let line  = mlist[2]
		else
			" otherwise parse up to next space
			let mlist = matchlist ( line, '^\(\S\+\)\(.*\)' )
			let curr .= mlist[1]
			let line  = mlist[2]
		endif
	endwhile

	" add last argument
	if curr != ''
		call add ( list, curr )
	endif

	return list
endfunction    " ----------  end of function s:ShellParseArgs  ----------

"-------------------------------------------------------------------------------
" s:SID : Return the <SID>.   {{{2
"
" Parameters:
"   -
" Returns:
"   SID - the SID of the script (string)
"-------------------------------------------------------------------------------

function! s:SID ()
	return matchstr ( expand('<sfile>'), '<SNR>\zs\d\+\ze_SID$' )
endfunction    " ----------  end of function s:SID  ----------

"-------------------------------------------------------------------------------
" s:UserInput : Input after a highlighted prompt.   {{{2
"
" Parameters:
"   prompt - the prompt (string)
"   text - the default input (string)
"   compl - completion (string, optional)
"   clist - list, if 'compl' is "customlist" (list, optional)
" Returns:
"   input - the user input, an empty sting if the user hit <ESC> (string)
"-------------------------------------------------------------------------------

function! s:UserInput ( prompt, text, ... )

	echohl Search                                         " highlight prompt
	call inputsave()                                      " preserve typeahead
	if a:0 == 0 || a:1 == ''
		let retval = input( a:prompt, a:text )
	elseif a:1 == 'customlist'
		let s:UserInputList = a:2
		let retval = input( a:prompt, a:text, 'customlist,<SNR>'.s:SID().'_UserInputEx' )
		let s:UserInputList = []
	else
		let retval = input( a:prompt, a:text, a:1 )
	endif
	call inputrestore()                                   " restore typeahead
	echohl None                                           " reset highlighting

	let retval  = substitute( retval, '^\s\+', "", "" )   " remove leading whitespaces
	let retval  = substitute( retval, '\s\+$', "", "" )   " remove trailing whitespaces

	return retval

endfunction    " ----------  end of function s:UserInput ----------

"-------------------------------------------------------------------------------
" s:UserInputEx : ex-command for s:UserInput.   {{{3
"-------------------------------------------------------------------------------
function! s:UserInputEx ( ArgLead, CmdLine, CursorPos )
	if empty( a:ArgLead )
		return copy( s:UserInputList )
	endif
	return filter( copy( s:UserInputList ), 'v:val =~ ''\V\<'.escape(a:ArgLead,'\').'\w\*''' )
endfunction    " ----------  end of function s:UserInputEx  ----------
" }}}3
"-------------------------------------------------------------------------------

"-------------------------------------------------------------------------------
" s:WarningMsg : Print a warning/error message.   {{{2
"
" Parameters:
"   line1 - a line (string)
"   line2 - a line (string)
"   ...   - ...
" Returns:
"   -
"-------------------------------------------------------------------------------

function! s:WarningMsg ( ... )
	echohl WarningMsg
	echo join ( a:000, "\n" )
	echohl None
endfunction    " ----------  end of function s:WarningMsg  ----------

" }}}2
"-------------------------------------------------------------------------------

"-------------------------------------------------------------------------------
" === Common functions ===   {{{1
"-------------------------------------------------------------------------------

"-------------------------------------------------------------------------------
" s:CodeSnippet : Code snippets.   {{{2
"
" Parameters:
"   action - "insert", "create", "vcreate", "view", or "edit" (string)
" Returns:
"   -
"-------------------------------------------------------------------------------
function! s:CodeSnippet ( action )

	"-------------------------------------------------------------------------------
	" setup
	"-------------------------------------------------------------------------------

	" the snippet directory
	let cs_dir    = s:BASH_CodeSnippets
	let cs_browse = s:BASH_GuiSnippetBrowser

	" check directory
	if ! isdirectory ( cs_dir )
		return s:ErrorMsg (
					\ 'Code snippet directory '.cs_dir.' does not exist.',
					\ '(Please create it.)' )
	endif

	" save option 'browsefilter'
	if has( 'browsefilter' ) && exists( 'b:browsefilter' )
		let browsefilter_save = b:browsefilter
		let b:browsefilter    = '*'
	endif

	"-------------------------------------------------------------------------------
	" do action
	"-------------------------------------------------------------------------------

	if a:action == 'insert'

		"-------------------------------------------------------------------------------
		" action "insert"
		"-------------------------------------------------------------------------------

		" select file
		if has('browse') && cs_browse == 'gui'
			let snippetfile = browse ( 0, 'insert a code snippet', cs_dir, '' )
		else
			let snippetfile = s:UserInput ( 'insert snippet ', cs_dir, 'file' )
		endif

		" insert snippet
		if filereadable(snippetfile)
			let linesread = line('$')

			let old_cpoptions = &cpoptions            " prevent the alternate buffer from being set to this files
			setlocal cpoptions-=a

			exe 'read '.snippetfile

			let &cpoptions = old_cpoptions            " restore previous options

			let linesread = line('$') - linesread - 1 " number of lines inserted

			" indent lines
			if linesread >= 0 && match( snippetfile, '\.\(ni\|noindent\)$' ) < 0
				silent exe 'normal! ='.linesread.'+'
			endif
		endif

		" delete first line if empty
		if line('.') == 2 && getline(1) =~ '^$'
			silent exe ':1,1d'
		endif

	elseif a:action == 'create' || a:action == 'vcreate'

		"-------------------------------------------------------------------------------
		" action "create" or "vcreate"
		"-------------------------------------------------------------------------------

		" select file
		if has('browse') && cs_browse == 'gui'
			let snippetfile = browse ( 1, 'create a code snippet', cs_dir, '' )
		else
			let snippetfile = s:UserInput ( 'create snippet ', cs_dir, 'file' )
		endif

		" create snippet
		if ! empty( snippetfile )
			" new file or overwrite?
			if ! filereadable( snippetfile ) || confirm( 'File '.snippetfile.' exists! Overwrite? ', "&Cancel\n&No\n&Yes" ) == 3
				if a:action == 'create' && confirm( 'Write whole file as a snippet? ', "&Cancel\n&No\n&Yes" ) == 3
					exe 'write! '.fnameescape( snippetfile )
				elseif a:action == 'vcreate'
					exe "'<,'>write! ".fnameescape( snippetfile )
				endif
			endif
		endif

	elseif a:action == 'view' || a:action == 'edit'

		"-------------------------------------------------------------------------------
		" action "view" or "edit"
		"-------------------------------------------------------------------------------
		if a:action == 'view' | let saving = 0
		else                  | let saving = 1 | endif

		" select file
		if has('browse') && cs_browse == 'gui'
			let snippetfile = browse ( saving, a:action.' a code snippet', cs_dir, '' )
		else
			let snippetfile = s:UserInput ( a:action.' snippet ', cs_dir, 'file' )
		endif

		" open file
		if ! empty( snippetfile )
			exe 'split | '.a:action.' '.fnameescape( snippetfile )
		endif
	else
		call s:ErrorMsg ( 'Unknown action "'.a:action.'".' )
	endif

	"-------------------------------------------------------------------------------
	" wrap up
	"-------------------------------------------------------------------------------

	" restore option 'browsefilter'
	if has( 'browsefilter' ) && exists( 'b:browsefilter' )
		let b:browsefilter = browsefilter_save
	endif

endfunction   " ----------  end of function s:CodeSnippet  ----------

"-------------------------------------------------------------------------------
" s:Hardcopy : Generate PostScript document from current buffer.   {{{2
"
" Under windows, display the printer dialog.
"
" Parameters:
"   mode - "n" : print complete buffer, "v" : print marked area (string)
" Returns:
"   -
"-------------------------------------------------------------------------------
function! s:Hardcopy ( mode )

	let outfile = expand("%:t")

	" check the buffer
	if ! s:MSWIN && empty ( outfile )
		return s:ImportantMsg ( 'The buffer has no filename.' )
	endif

	" save current settings
	let printheader_saved = &g:printheader

	let &g:printheader = g:BASH_Printheader

	if s:MSWIN
		" we simply call hardcopy, which will open the systems printing dialog
		if a:mode == 'n'
			silent exe  'hardcopy'
		elseif a:mode == 'v'
			silent exe  "'<,'>hardcopy"
		endif
	else

		" directory to print to
		let outdir = getcwd()
		if filewritable ( outdir ) != 2
			let outdir = $HOME
		endif

		let psfile = outdir.'/'.outfile.'.ps'

		if a:mode == 'n'
			silent exe  'hardcopy > '.psfile
			call s:ImportantMsg ( 'file "'.outfile.'" printed to "'.psfile.'"' )
		elseif a:mode == 'v'
			silent exe  "'<,'>hardcopy > ".psfile
			call s:ImportantMsg ( 'file "'.outfile.'" (lines '.line("'<").'-'.line("'>").') printed to "'.psfile.'"' )
		endif
	endif

	" restore current settings
	let &g:printheader = printheader_saved

endfunction   " ----------  end of function s:Hardcopy  ----------

"-------------------------------------------------------------------------------
" s:MakeExecutable : Make the script executable.   {{{2
"-------------------------------------------------------------------------------
function! s:MakeExecutable ()

	if ! executable ( 'chmod' )
		return s:ErrorMsg ( 'Command "chmod" not executable.' )
	endif

	let filename = expand("%:p")

	if executable ( filename )
		let from_state = 'executable'
		let to_state   = 'NOT executable'
		let cmd        = 'chmod -x'
	else
		let from_state = 'NOT executable'
		let to_state   = 'executable'
		let cmd        = 'chmod u+x'
	endif

	if s:UserInput( '"'.filename.'" is '.from_state.'. Make it '.to_state.' [y/n] : ', 'y' ) == 'y'

		" run the command
		silent exe '!'.cmd.' '.shellescape(filename)

		" successful?
		if v:shell_error
			" confirmation for the user
			call s:ErrorMsg ( 'Could not make "'.filename.'" '.to_state.'!' )
		else
			" reload the file, otherwise the message will not be visible
			if &autoread && ! &l:modified
				silent exe "edit"
			endif
			" confirmation for the user
			call s:ImportantMsg ( 'Made "'.filename.'" '.to_state.'.' )
		endif
		"
	endif

endfunction   " ----------  end of function s:MakeExecutable  ----------

"-------------------------------------------------------------------------------
" s:XtermSize : Set xterm size.   {{{2
"-------------------------------------------------------------------------------
function! s:XtermSize ()
	let regex = '-geometry\s\+\zs\d\+x\d\+'
	let geom = matchstr ( g:Xterm_Options, regex )
	let geom = substitute ( geom, 'x', ' ', "" )

	let answer = s:UserInput ( "   xterm size (COLUMNS LINES) : ", geom, '' )
	while match( answer, '^\s*\d\+\s\+\d\+\s*$' ) < 0
		let answer = s:UserInput ( " + xterm size (COLUMNS LINES) : ", geom, '' )
	endwhile

	let answer  = substitute ( answer, '^\s\+', '', '' )   " remove leading whitespaces
	let answer  = substitute ( answer, '\s\+$', '', '' )   " remove trailing whitespaces
	let answer  = substitute ( answer, '\s\+', 'x', '' )   " replace inner whitespaces
	let g:Xterm_Options = substitute ( g:Xterm_Options, regex, answer , 'g' )
endfunction    " ----------  end of function  s:XtermSize  ----------

" }}}2
"-------------------------------------------------------------------------------

"-------------------------------------------------------------------------------
" === Module setup ===   {{{1
"-------------------------------------------------------------------------------

"-------------------------------------------------------------------------------
" == Platform specific items ==   {{{2
"-------------------------------------------------------------------------------

let s:MSWIN = has("win16") || has("win32")   || has("win64")     || has("win95")
let s:UNIX  = has("unix")  || has("macunix") || has("win32unix")

let s:installation            = '*undefined*'
let s:plugin_dir              = ''
let s:BASH_GlobalTemplateFile = ''
let s:BASH_LocalTemplateFile  = ''
let s:BASH_CustomTemplateFile = ''                " the custom templates
let s:BASH_FilenameEscChar    = ''

if s:MSWIN
	" ==========  MS Windows  ======================================================

	let s:plugin_dir = substitute( expand('<sfile>:p:h:h'), '\', '/', 'g' )

	" change '\' to '/' to avoid interpretation as escape character
	if match(	substitute( expand("<sfile>"), '\', '/', 'g' ),
				\		substitute( expand("$HOME"),   '\', '/', 'g' ) ) == 0
		"
		" USER INSTALLATION ASSUMED
		let s:installation            = 'local'
		let s:BASH_LocalTemplateFile  = s:plugin_dir.'/bash-support/templates/Templates'
		let s:BASH_CustomTemplateFile = $HOME.'/vimfiles/templates/bash.templates'
	else
		"
		" SYSTEM WIDE INSTALLATION
		let s:installation            = 'system'
		let s:BASH_GlobalTemplateFile = s:plugin_dir.'/bash-support/templates/Templates'
		let s:BASH_LocalTemplateFile  = $HOME.'/vimfiles/bash-support/templates/Templates'
		let s:BASH_CustomTemplateFile = $HOME.'/vimfiles/templates/bash.templates'
	endif

	let s:BASH_FilenameEscChar    = ''
	let s:BASH_Display            = ''
	let s:BASH_ManualReader       = 'man.exe'
	let s:BASH_Executable         = 'bash.exe'
else
	" ==========  Linux/Unix  ======================================================

	let s:plugin_dir = expand('<sfile>:p:h:h')

	if match( expand("<sfile>"), resolve( expand("$HOME") ) ) == 0
		"
		" USER INSTALLATION ASSUMED
		let s:installation            = 'local'
		let s:BASH_LocalTemplateFile  = s:plugin_dir.'/bash-support/templates/Templates'
		let s:BASH_CustomTemplateFile = $HOME.'/.vim/templates/bash.templates'
	else
		"
		" SYSTEM WIDE INSTALLATION
		let s:installation            = 'system'
		let s:BASH_GlobalTemplateFile = s:plugin_dir.'/bash-support/templates/Templates'
		let s:BASH_LocalTemplateFile  = $HOME.'/.vim/bash-support/templates/Templates'
		let s:BASH_CustomTemplateFile = $HOME.'/.vim/templates/bash.templates'
	endif

	let s:BASH_Executable         = $SHELL
	let s:BASH_FilenameEscChar    = ' \%#[]'
	let s:BASH_Display            = $DISPLAY
	let s:BASH_ManualReader       = '/usr/bin/man'
endif

let s:BASH_AdditionalTemplates = mmtemplates#config#GetFt ( 'bash' )
let s:BASH_CodeSnippets        = s:plugin_dir.'/bash-support/codesnippets/'

"-------------------------------------------------------------------------------
" == Various settings ==   {{{2
"-------------------------------------------------------------------------------

"-------------------------------------------------------------------------------
" Use of dictionaries   {{{3
"
" - keyword completion is enabled by the function 's:CreateAdditionalMaps' below
"-------------------------------------------------------------------------------

if !exists("g:BASH_Dictionary_File")
	let g:BASH_Dictionary_File = s:plugin_dir.'/bash-support/wordlists/bash-keywords.list'
endif

"-------------------------------------------------------------------------------
" User configurable options   {{{3
"-------------------------------------------------------------------------------

let s:BASH_CreateMenusDelayed	= 'yes'
let s:BASH_GuiSnippetBrowser 	= 'gui'             " gui / commandline
let s:BASH_LoadMenus         	= 'yes'             " load the menus?
let s:BASH_RootMenu          	= '&Bash'           " name of the root menu
let s:BASH_Debugger           = 'term'
let s:BASH_bashdb             = 'bashdb'

if s:MSWIN
	let s:BASH_OutputMethodList = [ 'vim-io', 'vim-qf', 'buffer' ]
else
	let s:BASH_OutputMethodList = [ 'vim-io', 'vim-qf', 'buffer', 'xterm' ]
endif
if has ( 'terminal' ) && ! s:MSWIN              " :TODO:25.09.2017 16:16:WM: enable Windows, check how to start jobs with arguments under Windows
	let s:BASH_OutputMethodList += [ 'terminal' ]
endif
call sort ( s:BASH_OutputMethodList )
" :TODO:28.09.2017 18:33:WM: Windows defaults (was 'xterm', ran shell in a separate window!?), check running under Windows,
let s:BASH_OutputMethod           = 'vim-io'     " 'vim-io', 'vim-qf', 'buffer' or ... (see 's:BASH_OutputMethodList')
let s:BASH_DirectRun              = 'no'         " 'yes' or 'no'
let s:BASH_LineEndCommColDefault	= 49
let s:BASH_TemplateJumpTarget 		= ''
let s:BASH_Errorformat            = '%f: %[%^0-9]%# %l:%m,%f: %l:%m,%f:%l:%m,%f[%l]:%m'
let s:BASH_Wrapper                = s:plugin_dir.'/bash-support/scripts/wrapper.sh'
let s:BASH_InsertFileHeader       = 'yes'
let s:BASH_Ctrl_j                 = 'yes'
let s:BASH_Ctrl_d                 = 'yes'
let s:BASH_SyntaxCheckOptionsGlob = ''

if ! exists ( 's:MenuVisible' )
	let s:MenuVisible = 0                         " menus are not visible at the moment
endif

"-------------------------------------------------------------------------------
" Get user configuration   {{{3
"-------------------------------------------------------------------------------

call s:GetGlobalSetting ( 'BASH_Debugger' )
call s:GetGlobalSetting ( 'BASH_bashdb' )
call s:GetGlobalSetting ( 'BASH_SyntaxCheckOptionsGlob' )
call s:GetGlobalSetting ( 'BASH_Executable' )
call s:GetGlobalSetting ( 'BASH_InsertFileHeader' )
call s:GetGlobalSetting ( 'BASH_Ctrl_j' )
call s:GetGlobalSetting ( 'BASH_Ctrl_d' )
call s:GetGlobalSetting ( 'BASH_CodeSnippets' )
call s:GetGlobalSetting ( 'BASH_GuiSnippetBrowser' )
call s:GetGlobalSetting ( 'BASH_LoadMenus' )
call s:GetGlobalSetting ( 'BASH_RootMenu' )
call s:GetGlobalSetting ( 'BASH_ManualReader' )
call s:GetGlobalSetting ( 'BASH_OutputMethod', 'BASH_OutputGvim' )
call s:GetGlobalSetting ( 'BASH_OutputMethod' )
call s:GetGlobalSetting ( 'BASH_GlobalTemplateFile' )
call s:GetGlobalSetting ( 'BASH_LocalTemplateFile' )
call s:GetGlobalSetting ( 'BASH_CustomTemplateFile' )
call s:GetGlobalSetting ( 'BASH_CreateMenusDelayed' )
call s:GetGlobalSetting ( 'BASH_LineEndCommColDefault' )

call s:ApplyDefaultSetting ( 'BASH_MapLeader', '' )       " default: do not overwrite 'maplocalleader'
call s:ApplyDefaultSetting ( 'BASH_Printheader', "%<%f%h%m%<  %=%{strftime('%x %X')}     Page %N" )

if s:BASH_OutputMethod == 'vim'
	let s:BASH_OutputMethod = 'vim-qf'
endif

"-------------------------------------------------------------------------------
" Xterm   {{{3
"-------------------------------------------------------------------------------

let s:Xterm_Executable   = 'xterm'
let s:BASH_XtermDefaults = '-fa courier -fs 12 -geometry 80x24'

" check 'g:BASH_XtermDefaults' for backwards compatibility
if ! exists ( 'g:Xterm_Options' )
	call s:GetGlobalSetting ( 'BASH_XtermDefaults' )
	" set default geometry if not specified
	if match( s:BASH_XtermDefaults, "-geometry\\s\\+\\d\\+x\\d\\+" ) < 0
		let s:BASH_XtermDefaults  = s:BASH_XtermDefaults." -geometry 80x24"
	endif
endif

call s:GetGlobalSetting ( 'Xterm_Executable' )
call s:ApplyDefaultSetting ( 'Xterm_Options', s:BASH_XtermDefaults )

" }}}3
"-------------------------------------------------------------------------------

" }}}2
"-------------------------------------------------------------------------------

"-------------------------------------------------------------------------------
" s:AdjustLineEndComm : Adjust end-of-line comments.   {{{1
"-------------------------------------------------------------------------------

" patterns to ignore when adjusting line-end comments (incomplete):
let s:AlignRegex = [
	\	'\$#' ,
	\	'\${.*}'  ,
	\	"'\\%(\\\\'\\|[^']\\)*'"  ,
	\	'"\%(\\.\|[^"]\)*"'  ,
	\	'`[^`]\+`' ,
	\	]

function! s:AdjustLineEndComm ( ) range

	" comment character (for use in regular expression)
	let cc = '#'                       " start of a Bash comment
	"
	" patterns to ignore when adjusting line-end comments (maybe incomplete):
	let align_regex = join( s:AlignRegex, '\|' )
	"
	" local position
	if !exists( 'b:BASH_LineEndCommentColumn' )
		let b:BASH_LineEndCommentColumn = s:BASH_LineEndCommColDefault
	endif
	let correct_idx = b:BASH_LineEndCommentColumn
	"
	" === plug-in specific code ends here                 ===
	" === the behavior is governed by the variables above ===
	"
	" save the cursor position
	let save_cursor = getpos('.')
	"
	for line in range( a:firstline, a:lastline )
		silent exe ':'.line
		"
		let linetxt = getline('.')
		"
		" "pure" comment line left unchanged
		if match ( linetxt, '^\s*'.cc ) == 0
			"echo 'line '.line.': "pure" comment'
			continue
		endif
		"
		let b_idx1 = 1 + match ( linetxt, '\s*'.cc.'.*$', 0 )
		let b_idx2 = 1 + match ( linetxt,       cc.'.*$', 0 )
		"
		" not found?
		if b_idx1 == 0
			"echo 'line '.line.': no end-of-line comment'
			continue
		endif
		"
		" walk through ignored patterns
		let idx_start = 0
		"
		while 1
			let this_start = match ( linetxt, align_regex, idx_start )
			"
			if this_start == -1
				break
			else
				let idx_start = matchend ( linetxt, align_regex, idx_start )
				"echo 'line '.line.': ignoring >>>'.strpart(linetxt,this_start,idx_start-this_start).'<<<'
			endif
		endwhile
		"
		let b_idx1 = 1 + match ( linetxt, '\s*'.cc.'.*$', idx_start )
		let b_idx2 = 1 + match ( linetxt,       cc.'.*$', idx_start )
		"
		" not found?
		if b_idx1 == 0
			"echo 'line '.line.': no end-of-line comment'
			continue
		endif
		"
		call cursor ( line, b_idx2 )
		let v_idx2 = virtcol('.')
		"
		" do b_idx1 last, so the cursor is in the right position for substitute below
		call cursor ( line, b_idx1 )
		let v_idx1 = virtcol('.')
		"
		" already at right position?
		if ( v_idx2 == correct_idx )
			"echo 'line '.line.': already at right position'
			continue
		endif
		" ... or line too long?
		if ( v_idx1 >  correct_idx )
			"echo 'line '.line.': line too long'
			continue
		endif
		"
		" substitute all whitespaces behind the cursor (regex '\%#') and the next character,
		" to ensure the match is at least one character long
		silent exe 'substitute/\%#\s*\(\S\)/'.repeat( ' ', correct_idx - v_idx1 ).'\1/'
		"echo 'line '.line.': adjusted'
		"
	endfor
	"
	" restore the cursor position
	call setpos ( '.', save_cursor )

endfunction   " ---------- end of function s:AdjustLineEndComm  ----------

"-------------------------------------------------------------------------------
" s:GetLineEndCommCol : Set end-of-line comment position.   {{{1
"-------------------------------------------------------------------------------
function! s:GetLineEndCommCol ()
	let actcol = virtcol(".")
	if actcol+1 == virtcol("$")
		let b:BASH_LineEndCommentColumn = ''
		while match( b:BASH_LineEndCommentColumn, '^\s*\d\+\s*$' ) < 0
			let b:BASH_LineEndCommentColumn = s:UserInput( 'start line-end comment at virtual column : ', actcol, '' )
		endwhile
	else
		let b:BASH_LineEndCommentColumn = virtcol(".")
	endif
	echomsg "line end comments will start at column  ".b:BASH_LineEndCommentColumn
endfunction   " ---------- end of function s:GetLineEndCommCol  ----------

"-------------------------------------------------------------------------------
" s:EndOfLineComment : Append end-of-line comments.   {{{1
"-------------------------------------------------------------------------------
function! s:EndOfLineComment ( ) range
	if !exists("b:BASH_LineEndCommentColumn")
		let b:BASH_LineEndCommentColumn = s:BASH_LineEndCommColDefault
	endif
	" ----- trim whitespaces -----
	exe a:firstline.','.a:lastline.'s/\s*$//'

	for line in range( a:lastline, a:firstline, -1 )
		silent exe ":".line
		if getline(line) !~ '^\s*$'
			let linelength = virtcol( [line, "$"] ) - 1
			let diff = 1
			if linelength < b:BASH_LineEndCommentColumn
				let diff = b:BASH_LineEndCommentColumn -1 -linelength
			endif
			exe "normal! ".diff."A "
			call mmtemplates#core#InsertTemplate(g:BASH_Templates, 'Comments.end-of-line comment')
		endif
	endfor
endfunction   " ---------- end of function s:EndOfLineComment  ----------

"-------------------------------------------------------------------------------
" s:CodeComment : Code -> Comment   {{{1
"-------------------------------------------------------------------------------
function! s:CodeComment() range
	" add '#' at the beginning of the lines
	for line in range( a:firstline, a:lastline )
		exe line.'s/^/#/'
	endfor
endfunction    " ----------  end of function s:CodeComment  ----------

"-------------------------------------------------------------------------------
" s:CommentCode : Comment -> Code   {{{1
"
" Parameters:
"   toggle - 0 : uncomment, 1 : toggle comment (integer)
"-------------------------------------------------------------------------------
function! s:CommentCode( toggle ) range
	for i in range( a:firstline, a:lastline )
		" :TRICKY:15.08.2014 17:17:WM:
		" Older version prior to 2.3 inserted a space after the quote when turning
		" a line into a comment. In order to deal with old code commented with this
		" feature, we use a special rule to delete "hidden" spaces before tabs.
		" Every other space which was inserted after a quote will be visible.
		if getline( i ) =~ '^# \t'
			silent exe i.'s/^# //'
		elseif getline( i ) =~ '^#'
			silent exe i.'s/^#//'
		elseif a:toggle
			silent exe i.'s/^/#/'
		endif
	endfor
endfunction    " ----------  end of function s:CommentCode  ----------

"-------------------------------------------------------------------------------
" s:EchoComment : Put statement in an echo.   {{{1
"-------------------------------------------------------------------------------
function! s:EchoComment ()
	let	line	= escape( getline("."), '"' )
	let	line	= substitute( line, '^\s*', '', '' )
	call setline( line("."), 'echo "'.line.'"' )
	silent exe "normal! =="
	return
endfunction   " ---------- end of function s:EchoComment  ----------

"-------------------------------------------------------------------------------
" s:RemoveEcho : Remove echo from statement.   {{{1
"-------------------------------------------------------------------------------
function! s:RemoveEcho ()
	let	line	= substitute( getline("."), '\\"', '"', 'g' )
	let	line	= substitute( line, '^\s*echo\s\+"', '', '' )
	let	line	= substitute( line, '"$', '', '' )
	call setline( line("."), line )
	silent exe "normal! =="
	return
endfunction   " ---------- end of function s:RemoveEcho  ----------

"-------------------------------------------------------------------------------
" s:Run : Run the current buffer.   {{{1
"
" Parameters:
"   args - command-line arguments (string)
"   mode - "n" : run complete buffer, "v" : run marked area (string)
" Returns:
"   -
"-------------------------------------------------------------------------------
function! s:Run ( args, mode, ... ) range

	silent exe 'update'   | " write source file if necessary
	cclose

	" prepare and check the executable
	if ! executable( s:BASH_Executable )
		return s:ErrorMsg (
					\ 'Command "'.s:BASH_Executable.'" not found. Not configured correctly?',
					\ 'Further information: :help g:BASH_Executable' )
	endif

	" get the mode (normal/visual) and the range
	let mode = a:mode

	if mode == 'c' && a:0 == 2
		" Vim command-line
		if a:1 <= a:2 && ! ( a:1 == 1 && a:2 == 1 )
			let line_f = a:1
			let line_l = a:2
			let mode = 'v'
		else
			let mode = 'n'
		end
	elseif mode == 'v'
		let line_f = a:firstline
		let line_l = a:lastline
	endif

	let args_interp = ''

	" prepare the file (and handle visual mode)
	if mode == 'v'
		let tmpfile = tempname()
		silent exe ":'<,'>write ".tmpfile

		"if s:BASH_DirectRun == 'yes'
		" :TODO:27.09.2017 23:33:WM: implement this, parse the shebang
			"let exec        = mlist[1]
			"let args_interp = ' '.mlist[2]
			"let arg_list = [ exec ] + s:ShellParseArgs ( mlist[2] )
		"else
			let exec = s:BASH_Executable
			let arg_list = [ exec ]
		"end
		let script = tmpfile
		let arg_list += [ tmpfile ]
	elseif s:BASH_DirectRun == 'yes' && executable ( expand ( '%:p' ) )
		let exec   = expand ( '%:p' )
		let script = ''
		let arg_list = [ exec ]
	else
		let exec   = s:BASH_Executable
		let script = shellescape ( expand ( '%' ) )
		let arg_list = [ exec, expand( '%' ) ]
	endif

	" the cmd.-line arguments
	if exists( 'b:BASH_InterpCmdLineArgs' )
		let args_interp .= ' '.b:BASH_InterpCmdLineArgs
	endif

	if a:args != ''
		let args_script = a:args
	elseif exists( 'b:BASH_ScriptCmdLineArgs' )
		let args_script = b:BASH_ScriptCmdLineArgs
	else
		let args_script = ''
	endif

	let errformat = s:BASH_Errorformat

	if s:BASH_OutputMethod == 'vim-io'

		" method : "vim - interactive"

		exe '!'.exec.args_interp.' '.script.' '.args_script

		if exists( 'tmpfile' )
			call delete ( tmpfile )                   " delete the tmpfile
		endif
	elseif s:BASH_OutputMethod == 'vim-qf'

		" method : "vim - quickfix"

		" run script
		let bash_output = system ( exec.args_interp.' '.script.' '.args_script )

		" successful?
		if v:shell_error == 0
			" echo script output
			echo bash_output
		else
			" save current settings
			let errorf_saved = &g:errorformat

			" run code checker
			let &g:errorformat = errformat

			silent exe 'cexpr bash_output'

			" restore current settings
			let &g:errorformat = errorf_saved

			botright cwindow
			cc
		endif

		if exists( 'tmpfile' )
			call delete ( tmpfile )                   " delete the tmpfile
		endif
	elseif s:BASH_OutputMethod == 'buffer'

		" method : "buffer"

		if bufwinnr ( 'Bash Output$' ) == -1
			" open buffer
			above new
			file Bash\ Output
			" TODO: name might exist on a different tab page

			" settings
			setlocal buftype=nofile
			setlocal noswapfile
			setlocal syntax=none
			setlocal tabstop=8

"			call Bash_SetMapLeader ()
"
"			" maps: quickfix list
"			nnoremap  <buffer>  <silent>  <LocalLeader>qf       :call <SID>OutputBufferErrors(0)<CR>
"			inoremap  <buffer>  <silent>  <LocalLeader>qf  <C-C>:call <SID>OutputBufferErrors(0)<CR>
"			vnoremap  <buffer>  <silent>  <LocalLeader>qf  <C-C>:call <SID>OutputBufferErrors(0)<CR>
"			nnoremap  <buffer>  <silent>  <LocalLeader>qj       :call <SID>OutputBufferErrors(1)<CR>
"			inoremap  <buffer>  <silent>  <LocalLeader>qj  <C-C>:call <SID>OutputBufferErrors(1)<CR>
"			vnoremap  <buffer>  <silent>  <LocalLeader>qj  <C-C>:call <SID>OutputBufferErrors(1)<CR>
"
"			call Bash_ResetMapLeader ()
		else
			" jump to window
			exe bufwinnr( 'Bash Output$' ).'wincmd w'
		endif

		setlocal modifiable

		silent exe '%delete _'
		silent exe '0r!'.exec.args_interp.' '.script.' '.args_script
		silent exe '$delete _'

		if v:shell_error == 0
			" jump to the first line of the output
			normal! gg

			setlocal nomodifiable
			setlocal nomodified
		else
			" jump to the last line of the output, where the error is mentioned
			normal! G

			" save current settings
			let errorf_saved  = &l:errorformat

			" run code checker
			let &l:errorformat = errformat

			silent exe 'cgetbuffer'

			" restore current settings
			let &l:errorformat = errorf_saved

			botright cwindow
			cc
		endif

		if exists( 'tmpfile' )
			call delete ( tmpfile )                   " delete the tmpfile
		endif
	elseif s:BASH_OutputMethod == 'terminal'

		" method : "terminal"

		try
			let arg_list += s:ShellParseArgs ( a:args )      " expand to a list
		catch /^ShellParseArgs:Syntax:/
			let msg = v:exception[ len( 'ShellParseArgs:Syntax:') : -1 ]
			return s:WarningMsg ( 'syntax error while parsing arguments: '.msg )
		catch /.*/
			return s:WarningMsg (
						\ "internal error (" . v:exception . ")",
						\ " - occurred at " . v:throwpoint )
		endtry

		let title = 'Bash Terminal - '.expand( '%:t' )
		if mode == 'v'
			let title  = title.' - lines '.line_f.'-'.line_l
		endif

		let buf_nr = term_start ( arg_list, {
					\ 'term_name' : title,
					\ } )

		" :TODO:27.09.2017 23:39:WM: needs to handle the tmpfile, use exit callback

	elseif s:BASH_OutputMethod == 'xterm'

		" method : "xterm"

		let title  = 'Bash'
		let rm_tmp = ''
		if mode == 'v'
			let title  = title.' - lines '.line_f.'-'.line_l
			let rm_tmp = '; rm '.tmpfile
		endif

		" :TODO:27.09.2017 23:39:WM: needs to handle the tmpfile, but Linux only so use 'rm'

		silent exe '!'.s:Xterm_Executable.' '.g:Xterm_Options
					\ .' -title '.shellescape( title )
					\ .' -e '.shellescape( exec.args_interp.' '.script.' '.args_script.' ; echo "" ; read -p "  ** PRESS ENTER **  " dummy '.rm_tmp ).' &'
	endif

	call s:Redraw ( 'r!', '' )                    " redraw in terminal

endfunction    " ----------  end of function s:Run  ----------

"-------------------------------------------------------------------------------
" s:ScriptCmdLineArguments : Set cmd.-line arguments for the script.   {{{1
"-------------------------------------------------------------------------------
function! s:ScriptCmdLineArguments ( args )
	let b:BASH_ScriptCmdLineArgs = a:args
endfunction    " ---------- end of function  s:ScriptCmdLineArguments  ----------

"-------------------------------------------------------------------------------
" s:InterpCmdLineArguments : Set cmd.-line arguments for the interpreter.   {{{1
"-------------------------------------------------------------------------------
function! s:InterpCmdLineArguments ( args )
	let b:BASH_InterpCmdLineArgs = a:args
endfunction    " ----------  end of function s:InterpCmdLineArguments ----------

"-------------------------------------------------------------------------------
" s:GetOutputMethodList : For cmd.-line completion.   {{{1
"-------------------------------------------------------------------------------
function! s:GetOutputMethodList (...)
	return join ( s:BASH_OutputMethodList, "\n" )
endfunction    " ----------  end of function s:GetOutputMethodList  ----------

"-------------------------------------------------------------------------------
" s:SetOutputMethod : Set s:BASH_OutputMethod   {{{1
"-------------------------------------------------------------------------------
function! s:SetOutputMethod ( method )

	if a:method == ''
		echo s:BASH_OutputMethod
		return
	endif

	" 'method' gives the output method
	if index ( s:BASH_OutputMethodList, a:method ) == -1
		return s:ErrorMsg ( 'Invalid option for output method: "'.a:method.'".' )
	endif

	let s:BASH_OutputMethod = a:method

	" update the menu header
	if ! has ( 'menu' ) || s:MenuVisible == 0
		return
	endif

	exe 'aunmenu '.s:BASH_RootMenu.'.Run.output\ method.Output\ Method'

	if s:BASH_OutputMethod == 'vim-io'
		let current = 'vim\ io'
	elseif s:BASH_OutputMethod == 'vim-qf'
		let current = 'vim\ qf'
	elseif s:BASH_OutputMethod == 'buffer'
		let current = 'buffer'
	elseif s:BASH_OutputMethod == 'terminal'
		let current = 'terminal'
	elseif s:BASH_OutputMethod == 'xterm'
		let current = 'xterm'
	endif

	exe 'anoremenu ...400 '.s:BASH_RootMenu.'.Run.output\ method.Output\ Method<TAB>(current\:\ '.current.') :echo "This is a menu header."<CR>'

endfunction    " ----------  end of function s:SetOutputMethod  ----------

"-------------------------------------------------------------------------------
" s:GetDirectRunList : For cmd.-line completion.   {{{1
"-------------------------------------------------------------------------------
function! s:GetDirectRunList (...)
	return "yes\nno"
endfunction    " ----------  end of function s:GetDirectRunList  ----------

"-------------------------------------------------------------------------------
" s:SetDirectRun : Set s:BASH_DirectRun   {{{1
"-------------------------------------------------------------------------------
function! s:SetDirectRun ( option )

	if a:option == ''
		echo s:BASH_DirectRun
		return
	endif

	" 'option' gives the setting
	if a:option != 'yes' && a:option != 'no'
		return s:ErrorMsg ( 'Invalid option for direct run: "'.a:option.'".' )
	endif

	let s:BASH_DirectRun = a:option

	" update the menu header
	if ! has ( 'menu' ) || s:MenuVisible == 0
		return
	endif

	exe 'aunmenu '.s:BASH_RootMenu.'.Run.direct\ run.Direct\ Run'

	let current = s:BASH_DirectRun

	exe 'anoremenu ...400 '.s:BASH_RootMenu.'.Run.direct\ run.Direct\ Run<TAB>(currently\:\ '.current.') :echo "This is a menu header."<CR>'

endfunction    " ----------  end of function s:SetDirectRun  ----------

"-------------------------------------------------------------------------------
" s:HelpPlugin : Plug-in help.   {{{1
"-------------------------------------------------------------------------------
function! s:HelpPlugin ()
	try
		help bashsupport
	catch
		exe 'helptags '.s:plugin_dir.'/doc'
		help bashsupport
	endtry
endfunction   " ----------  end of function s:HelpPlugin ----------

"------------------------------------------------------------------------------
"  === Templates API ===   {{{1
"------------------------------------------------------------------------------
"
"------------------------------------------------------------------------------
"  Bash_SetMapLeader   {{{2
"------------------------------------------------------------------------------
function! Bash_SetMapLeader ()
	if exists ( 'g:BASH_MapLeader' )
		call mmtemplates#core#SetMapleader ( g:BASH_MapLeader )
	endif
endfunction    " ----------  end of function Bash_SetMapLeader  ----------
"
"------------------------------------------------------------------------------
"  Bash_ResetMapLeader   {{{2
"------------------------------------------------------------------------------
function! Bash_ResetMapLeader ()
	if exists ( 'g:BASH_MapLeader' )
		call mmtemplates#core#ResetMapleader ()
	endif
endfunction    " ----------  end of function Bash_ResetMapLeader  ----------
" }}}2

"-------------------------------------------------------------------------------
" s:RereadTemplates : Initial loading of the templates.   {{{1
"-------------------------------------------------------------------------------
function! s:RereadTemplates ()

	"-------------------------------------------------------------------------------
	" setup template library
	"-------------------------------------------------------------------------------
	let g:BASH_Templates = mmtemplates#core#NewLibrary ( 'api_version', '1.0' )

	" mapleader
	if empty ( g:BASH_MapLeader )
		call mmtemplates#core#Resource ( g:BASH_Templates, 'set', 'property', 'Templates::Mapleader', '\' )
	else
		call mmtemplates#core#Resource ( g:BASH_Templates, 'set', 'property', 'Templates::Mapleader', g:BASH_MapLeader )
	endif

	" some metainfo
	call mmtemplates#core#Resource ( g:BASH_Templates, 'set', 'property', 'Templates::Wizard::PluginName',   'Bash' )
	call mmtemplates#core#Resource ( g:BASH_Templates, 'set', 'property', 'Templates::Wizard::FiletypeName', 'Bash' )
	call mmtemplates#core#Resource ( g:BASH_Templates, 'set', 'property', 'Templates::Wizard::FileCustomNoPersonal',   s:plugin_dir.'/bash-support/rc/custom.templates' )
	call mmtemplates#core#Resource ( g:BASH_Templates, 'set', 'property', 'Templates::Wizard::FileCustomWithPersonal', s:plugin_dir.'/bash-support/rc/custom_with_personal.templates' )
	call mmtemplates#core#Resource ( g:BASH_Templates, 'set', 'property', 'Templates::Wizard::FilePersonal',           s:plugin_dir.'/bash-support/rc/personal.templates' )
	call mmtemplates#core#Resource ( g:BASH_Templates, 'set', 'property', 'Templates::Wizard::CustomFileVariable',     'g:BASH_CustomTemplateFile' )

	" maps: special operations
	call mmtemplates#core#Resource ( g:BASH_Templates, 'set', 'property', 'Templates::RereadTemplates::Map', 'ntr' )
	call mmtemplates#core#Resource ( g:BASH_Templates, 'set', 'property', 'Templates::ChooseStyle::Map',     'nts' )
	call mmtemplates#core#Resource ( g:BASH_Templates, 'set', 'property', 'Templates::SetupWizard::Map',     'ntw' )

	" syntax: comments
	call mmtemplates#core#ChangeSyntax ( g:BASH_Templates, 'comment', '§' )

	" property: file skeletons
	call mmtemplates#core#Resource ( g:BASH_Templates, 'add', 'property', 'Bash::FileSkeleton::Script', 'Comments.shebang;Comments.file header; ;Skeleton.script-set' )

	"-------------------------------------------------------------------------------
	" load template library
	"-------------------------------------------------------------------------------

	" global templates (global installation only)
	if s:installation == 'system'
		call mmtemplates#core#ReadTemplates ( g:BASH_Templates, 'load', s:BASH_GlobalTemplateFile,
					\ 'name', 'global', 'map', 'ntg' )
	endif

	" local templates (optional for global installation)
	if s:installation == 'system'
		call mmtemplates#core#ReadTemplates ( g:BASH_Templates, 'load', s:BASH_LocalTemplateFile,
					\ 'name', 'local', 'map', 'ntl', 'optional', 'hidden' )
	else
		call mmtemplates#core#ReadTemplates ( g:BASH_Templates, 'load', s:BASH_LocalTemplateFile,
					\ 'name', 'local', 'map', 'ntl' )
	endif

	" additional templates (optional)
	if ! empty ( s:BASH_AdditionalTemplates )
		call mmtemplates#core#AddCustomTemplateFiles ( g:BASH_Templates, s:BASH_AdditionalTemplates, "Bash's additional templates" )
	endif

	" personal templates (shared across template libraries) (optional, existence of file checked by template engine)
	call mmtemplates#core#ReadTemplates ( g:BASH_Templates, 'personalization',
				\ 'name', 'personal', 'map', 'ntp' )

	" custom templates (optional, existence of file checked by template engine)
	call mmtemplates#core#ReadTemplates ( g:BASH_Templates, 'load', s:BASH_CustomTemplateFile,
				\ 'name', 'custom', 'map', 'ntc', 'optional' )

	"-------------------------------------------------------------------------------
	" further setup
	"-------------------------------------------------------------------------------

	" get the jump tags
	let s:BASH_TemplateJumpTarget = mmtemplates#core#Resource ( g:BASH_Templates, "jumptag" )[0]

	" get the builtin list
	let l = mmtemplates#core#Resource ( g:BASH_Templates, 'get', 'list', 'builtins' )

	if l[1] == ''
		let s:BuiltinList = l[0]
	else
		call s:ErrorMsg ( l[1] )
	endif

endfunction    " ----------  end of function s:RereadTemplates  ----------

"-------------------------------------------------------------------------------
" s:CheckTemplatePersonalization : Check whether the name, .. has been set.   {{{1
"-------------------------------------------------------------------------------

let s:DoneCheckTemplatePersonalization = 0

function! s:CheckTemplatePersonalization ()

	" check whether the templates are personalized
	if s:DoneCheckTemplatePersonalization
				\ || mmtemplates#core#ExpandText ( g:BASH_Templates, '|AUTHOR|' ) != 'YOUR NAME'
				\ || s:BASH_InsertFileHeader != 'yes'
		return
	endif

	let s:DoneCheckTemplatePersonalization = 1

	let maplead = mmtemplates#core#Resource ( g:BASH_Templates, 'get', 'property', 'Templates::Mapleader' )[0]

	redraw
	call s:ImportantMsg ( 'The personal details are not set in the template library. Use the map "'.maplead.'ntw".' )

endfunction    " ----------  end of function s:CheckTemplatePersonalization  ----------

"-------------------------------------------------------------------------------
" s:CheckAndRereadTemplates : Make sure the templates are loaded.   {{{1
"-------------------------------------------------------------------------------
function! s:CheckAndRereadTemplates ()
	if ! exists ( 'g:BASH_Templates' )
		call s:RereadTemplates()
	endif
endfunction    " ----------  end of function s:CheckAndRereadTemplates  ----------

"-------------------------------------------------------------------------------
" s:InsertFileHeader : Insert a file header.   {{{1
"-------------------------------------------------------------------------------
function! s:InsertFileHeader ()
	call s:CheckAndRereadTemplates()

	" prevent insertion for a file generated from a some error
	if isdirectory(expand('%:p:h')) && s:BASH_InsertFileHeader == 'yes'
		let templ_s = mmtemplates#core#Resource ( g:BASH_Templates, 'get', 'property', 'Bash::FileSkeleton::Script' )[0]

		" insert templates in reverse order, always above the first line
		" the last one to insert (the first in the list), will determine the
		" placement of the cursor
		let templ_l = split ( templ_s, ';' )
		for i in range ( len(templ_l)-1, 0, -1 )
			exe 1
			if -1 != match ( templ_l[i], '^\s\+$' )
				put! =''
			else
				call mmtemplates#core#InsertTemplate ( g:BASH_Templates, templ_l[i], 'placement', 'above' )
			endif
		endfor
		if len(templ_l) > 0
			set modified
		endif
	endif
endfunction    " ----------  end of function s:InsertFileHeader  ----------

"-------------------------------------------------------------------------------
" s:JumpForward : Jump to the next target.   {{{1
"
" If no target is found, jump behind the current string
"
" Parameters:
"   -
" Returns:
"   empty sting
"-------------------------------------------------------------------------------
function! s:JumpForward ()
	let match = search( s:BASH_TemplateJumpTarget, 'c' )
	if match > 0
		" remove the target
		call setline( match, substitute( getline('.'), s:BASH_TemplateJumpTarget, '', '' ) )
	else
		" try to jump behind parenthesis or strings
		call search( "[\]})\"'`]", 'W' )
		normal! l
	endif
	return ''
endfunction    " ----------  end of function s:JumpForward  ----------

"-------------------------------------------------------------------------------
" s:InitMenus : Initialize menus.   {{{1
"-------------------------------------------------------------------------------
function! s:InitMenus()
	"
	if ! has ( 'menu' )
		return
	endif
	"
 	"-------------------------------------------------------------------------------
	" preparation      {{{2
	"-------------------------------------------------------------------------------
	call mmtemplates#core#CreateMenus ( 'g:BASH_Templates', s:BASH_RootMenu, 'do_reset' )
	"
	" get the mapleader (correctly escaped)
	let [ esc_mapl, err ] = mmtemplates#core#Resource ( g:BASH_Templates, 'escaped_mapleader' )
	"
	exe 'amenu '.s:BASH_RootMenu.'.Bash  <Nop>'
	exe 'amenu '.s:BASH_RootMenu.'.-Sep00- <Nop>'
	"
 	"-------------------------------------------------------------------------------
	" menu headers     {{{2
	"-------------------------------------------------------------------------------
	"
	call mmtemplates#core#CreateMenus ( 'g:BASH_Templates', s:BASH_RootMenu, 'sub_menu', '&Comments', 'priority', 500 )
	" the other, automatically created menus go here; their priority is the standard priority 500
	call mmtemplates#core#CreateMenus ( 'g:BASH_Templates', s:BASH_RootMenu, 'sub_menu', 'S&nippets', 'priority', 600 )
	call mmtemplates#core#CreateMenus ( 'g:BASH_Templates', s:BASH_RootMenu, 'sub_menu', '&Run'     , 'priority', 700 )
	call mmtemplates#core#CreateMenus ( 'g:BASH_Templates', s:BASH_RootMenu, 'sub_menu', '&Help'    , 'priority', 800 )
	"
	"-------------------------------------------------------------------------------
	" comments     {{{2
 	"-------------------------------------------------------------------------------
	"
	let  head =  'noremenu <silent> '.s:BASH_RootMenu.'.Comments.'
	let ahead = 'anoremenu <silent> '.s:BASH_RootMenu.'.Comments.'
	let vhead = 'vnoremenu <silent> '.s:BASH_RootMenu.'.Comments.'
	let ihead = 'inoremenu <silent> '.s:BASH_RootMenu.'.Comments.'
	"
	exe ahead.'end-of-&line\ comment<Tab>'.esc_mapl.'cl                 :call <SID>EndOfLineComment()<CR>'
	exe vhead.'end-of-&line\ comment<Tab>'.esc_mapl.'cl                 :call <SID>EndOfLineComment()<CR>'

	exe ahead.'ad&just\ end-of-line\ com\.<Tab>'.esc_mapl.'cj           :call <SID>AdjustLineEndComm()<CR>'
	exe ihead.'ad&just\ end-of-line\ com\.<Tab>'.esc_mapl.'cj      <Esc>:call <SID>AdjustLineEndComm()<CR>'
	exe vhead.'ad&just\ end-of-line\ com\.<Tab>'.esc_mapl.'cj           :call <SID>AdjustLineEndComm()<CR>'
	exe  head.'&set\ end-of-line\ com\.\ col\.<Tab>'.esc_mapl.'cs  <Esc>:call <SID>GetLineEndCommCol()<CR>'
	"
	exe ahead.'-Sep01-						<Nop>'
	exe ahead.'&comment<TAB>'.esc_mapl.'cc															:call <SID>CodeComment()<CR>'
	exe vhead.'&comment<TAB>'.esc_mapl.'cc															:call <SID>CodeComment()<CR>'
	exe ahead.'&uncomment<TAB>'.esc_mapl.'co														:call <SID>CommentCode(0)<CR>'
	exe vhead.'&uncomment<TAB>'.esc_mapl.'co														:call <SID>CommentCode(0)<CR>'
	exe ahead.'-Sep02-						<Nop>'
	"
	"-------------------------------------------------------------------------------
	" generate menus from the templates
 	"-------------------------------------------------------------------------------
	"
	call mmtemplates#core#CreateMenus ( 'g:BASH_Templates', s:BASH_RootMenu, 'do_templates' )
	"
	"-------------------------------------------------------------------------------
	" snippets     {{{2
	"-------------------------------------------------------------------------------

	if !empty(s:BASH_CodeSnippets)
		exe "amenu  <silent> ".s:BASH_RootMenu.'.S&nippets.&read\ code\ snippet<Tab>'.esc_mapl.'nr       :call <SID>CodeSnippet("insert")<CR>'
		exe "imenu  <silent> ".s:BASH_RootMenu.'.S&nippets.&read\ code\ snippet<Tab>'.esc_mapl.'nr  <C-C>:call <SID>CodeSnippet("insert")<CR>'
		exe "amenu  <silent> ".s:BASH_RootMenu.'.S&nippets.&view\ code\ snippet<Tab>'.esc_mapl.'nv       :call <SID>CodeSnippet("view")<CR>'
		exe "imenu  <silent> ".s:BASH_RootMenu.'.S&nippets.&view\ code\ snippet<Tab>'.esc_mapl.'nv  <C-C>:call <SID>CodeSnippet("view")<CR>'
		exe "amenu  <silent> ".s:BASH_RootMenu.'.S&nippets.&write\ code\ snippet<Tab>'.esc_mapl.'nw      :call <SID>CodeSnippet("create")<CR>'
		exe "imenu  <silent> ".s:BASH_RootMenu.'.S&nippets.&write\ code\ snippet<Tab>'.esc_mapl.'nw <C-C>:call <SID>CodeSnippet("create")<CR>'
		exe "vmenu  <silent> ".s:BASH_RootMenu.'.S&nippets.&write\ code\ snippet<Tab>'.esc_mapl.'nw <C-C>:call <SID>CodeSnippet("vcreate")<CR>'
		exe "amenu  <silent> ".s:BASH_RootMenu.'.S&nippets.&edit\ code\ snippet<Tab>'.esc_mapl.'ne       :call <SID>CodeSnippet("edit")<CR>'
		exe "imenu  <silent> ".s:BASH_RootMenu.'.S&nippets.&edit\ code\ snippet<Tab>'.esc_mapl.'ne  <C-C>:call <SID>CodeSnippet("edit")<CR>'
		exe "amenu  <silent> ".s:BASH_RootMenu.'.S&nippets.-SepSnippets-                       :'
	endif

	"-------------------------------------------------------------------------------
	" templates
	"-------------------------------------------------------------------------------

	call mmtemplates#core#CreateMenus ( 'g:BASH_Templates', s:BASH_RootMenu, 'do_specials', 'specials_menu', 'S&nippets' )

	"-------------------------------------------------------------------------------
	" run     {{{2
	"-------------------------------------------------------------------------------

	let ahead = 'anoremenu <silent> '.s:BASH_RootMenu.'.Run.'
	let vhead = 'vnoremenu <silent> '.s:BASH_RootMenu.'.Run.'
	let ihead = 'inoremenu <silent> '.s:BASH_RootMenu.'.Run.'

	exe ahead.'save\ +\ &run\ script<Tab>'.esc_mapl.'rr            :call <SID>Run("","n")<CR>'
	exe vhead.'save\ +\ &run\ script<Tab>'.esc_mapl.'rr       <C-C>:call <SID>Run("","v")<CR>'
	exe ihead.'save\ +\ &run\ script<Tab>'.esc_mapl.'rr       <C-C>:call <SID>Run("","n")<CR>'

	exe " menu          ".s:BASH_RootMenu.'.&Run.script\ cmd\.\ line\ &arg\.<Tab>'.esc_mapl.'ra       :BashScriptArguments<Space>'
	exe "imenu          ".s:BASH_RootMenu.'.&Run.script\ cmd\.\ line\ &arg\.<Tab>'.esc_mapl.'ra  <C-C>:BashScriptArguments<Space>'
	"
	exe " menu          ".s:BASH_RootMenu.'.&Run.Bash\ cmd\.\ line\ &arg\.<Tab>'.esc_mapl.'rba                  :BashInterpArguments<Space>'
	exe "imenu          ".s:BASH_RootMenu.'.&Run.Bash\ cmd\.\ line\ &arg\.<Tab>'.esc_mapl.'rba             <C-C>:BashInterpArguments<Space>'
	"
  exe " menu <silent> ".s:BASH_RootMenu.'.&Run.update,\ check\ &syntax<Tab>'.esc_mapl.'rc          :call BASH_SyntaxCheck()<CR>'
  exe "imenu <silent> ".s:BASH_RootMenu.'.&Run.update,\ check\ &syntax<Tab>'.esc_mapl.'rc     <C-C>:call BASH_SyntaxCheck()<CR>'
	exe " menu <silent> ".s:BASH_RootMenu.'.&Run.syntax\ check\ o&ptions<Tab>'.esc_mapl.'rco         :call BASH_SyntaxCheckOptionsLocal()<CR>'
	exe "imenu <silent> ".s:BASH_RootMenu.'.&Run.syntax\ check\ o&ptions<Tab>'.esc_mapl.'rco    <C-C>:call BASH_SyntaxCheckOptionsLocal()<CR>'

	if	!s:MSWIN
		exe "amenu <silent> ".s:BASH_RootMenu.'.&Run.start\ &debugger<Tab>'.esc_mapl.'rd                   :call BASH_Debugger()<CR>'
		exe "amenu <silent> ".s:BASH_RootMenu.'.&Run.make\ script\ &exec\./not\ exec\.<Tab>'.esc_mapl.'re  :call <SID>MakeExecutable()<CR>'
	endif

	exe ahead.'-SEP-SETTINGS-   :'

	" create a dummy menu header for the "output method" sub-menu
	exe ahead.'&output\ method<TAB>'.esc_mapl.'ro.Output\ Method   :'
	exe ahead.'&output\ method<TAB>'.esc_mapl.'ro.-SepHead-        :'
	" create a dummy menu header for the "direct run" sub-menu
	exe ahead.'&direct\ run<TAB>'.esc_mapl.'rd.Direct\ Run   :'
	exe ahead.'&direct\ run<TAB>'.esc_mapl.'rd.-SepHead-     :'

	if index ( s:BASH_OutputMethodList, 'xterm' ) > -1
		exe ahead.'x&term\ size<Tab>'.esc_mapl.'rx                       :call <SID>XtermSize()<CR>'
		exe ihead.'x&term\ size<Tab>'.esc_mapl.'rx                  <C-C>:call <SID>XtermSize()<CR>'
	endif

	exe ahead.'-SEP1-   :'
	if s:MSWIN
		exe ahead.'&hardcopy\ to\ printer<Tab>'.esc_mapl.'rh        <C-C>:call <SID>Hardcopy("n")<CR>'
		exe vhead.'&hardcopy\ to\ printer<Tab>'.esc_mapl.'rh        <C-C>:call <SID>Hardcopy("v")<CR>'
	else
		exe ahead.'&hardcopy\ to\ FILENAME\.ps<Tab>'.esc_mapl.'rh   <C-C>:call <SID>Hardcopy("n")<CR>'
		exe vhead.'&hardcopy\ to\ FILENAME\.ps<Tab>'.esc_mapl.'rh   <C-C>:call <SID>Hardcopy("v")<CR>'
	endif

	exe ahead.'-SEP2-   :'
	exe ahead.'plugin\ &settings<Tab>'.esc_mapl.'rs                   :call BASH_Settings(0)<CR>'

	" run -> output method

	exe ahead.'output\ method.vim\ &io<TAB>interactive       :call <SID>SetOutputMethod("vim-io")<CR>'
	exe ihead.'output\ method.vim\ &io<TAB>interactive  <Esc>:call <SID>SetOutputMethod("vim-io")<CR>'
	exe ahead.'output\ method.vim\ &qf<TAB>quickfix          :call <SID>SetOutputMethod("vim-qf")<CR>'
	exe ihead.'output\ method.vim\ &qf<TAB>quickfix     <Esc>:call <SID>SetOutputMethod("vim-qf")<CR>'
	exe ahead.'output\ method.&buffer<TAB>quickfix           :call <SID>SetOutputMethod("buffer")<CR>'
	exe ihead.'output\ method.&buffer<TAB>quickfix      <Esc>:call <SID>SetOutputMethod("buffer")<CR>'
	if index ( s:BASH_OutputMethodList, 'terminal' ) > -1
		exe ahead.'output\ method.&terminal<TAB>interactive       :call <SID>SetOutputMethod("terminal")<CR>'
		exe ihead.'output\ method.&terminal<TAB>interactive  <Esc>:call <SID>SetOutputMethod("terminal")<CR>'
	endif
	if index ( s:BASH_OutputMethodList, 'xterm' ) > -1
		exe ahead.'output\ method.&xterm<TAB>interactive       :call <SID>SetOutputMethod("xterm")<CR>'
		exe ihead.'output\ method.&xterm<TAB>interactive  <Esc>:call <SID>SetOutputMethod("xterm")<CR>'
	endif

	" run -> direct run

	exe ahead.'direct\ run.&yes<TAB>use\ executable\ scripts         :call <SID>SetDirectRun("yes")<CR>'
	exe ihead.'direct\ run.&yes<TAB>use\ executable\ scripts    <Esc>:call <SID>SetDirectRun("yes")<CR>'
	exe ahead.'direct\ run.&no<TAB>always\ use\ bash                 :call <SID>SetDirectRun("no")<CR>'
	exe ihead.'direct\ run.&no<TAB>always\ use\ bash            <Esc>:call <SID>SetDirectRun("no")<CR>'

	" deletes the dummy menu header and displays the current options
	" in the menu header of the sub-menus
	call s:SetOutputMethod ( s:BASH_OutputMethod )
	call s:SetDirectRun ( s:BASH_DirectRun )

	"-------------------------------------------------------------------------------
 	" comments     {{{2
 	"-------------------------------------------------------------------------------
	exe " noremenu ".s:BASH_RootMenu.'.&Comments.&echo\ "<line>"<Tab>'.esc_mapl.'ce       :call <SID>EchoComment()<CR>j'
	exe "inoremenu ".s:BASH_RootMenu.'.&Comments.&echo\ "<line>"<Tab>'.esc_mapl.'ce  <C-C>:call <SID>EchoComment()<CR>j'
	exe " noremenu ".s:BASH_RootMenu.'.&Comments.&remove\ echo<Tab>'.esc_mapl.'cr         :call <SID>RemoveEcho()<CR>j'
	exe "inoremenu ".s:BASH_RootMenu.'.&Comments.&remove\ echo<Tab>'.esc_mapl.'cr    <C-C>:call <SID>RemoveEcho()<CR>j'
	"
 	"-------------------------------------------------------------------------------
 	" help     {{{2
 	"-------------------------------------------------------------------------------
	"
	exe " menu  <silent>  ".s:BASH_RootMenu.'.&Help.&Bash\ manual<Tab>'.esc_mapl.'hb                    :call BASH_help("bash")<CR>'
	exe "imenu  <silent>  ".s:BASH_RootMenu.'.&Help.&Bash\ manual<Tab>'.esc_mapl.'hb               <C-C>:call BASH_help("bash")<CR>'
	"
	exe " menu  <silent>  ".s:BASH_RootMenu.'.&Help.&help\ (Bash\ builtins)<Tab>'.esc_mapl.'hh          :call BASH_help("help")<CR>'
	exe "imenu  <silent>  ".s:BASH_RootMenu.'.&Help.&help\ (Bash\ builtins)<Tab>'.esc_mapl.'hh     <C-C>:call BASH_help("help")<CR>'
	"
	exe " menu  <silent>  ".s:BASH_RootMenu.'.&Help.&manual\ (utilities)<Tab>'.esc_mapl.'hm             :call BASH_help("man")<CR>'
	exe "imenu  <silent>  ".s:BASH_RootMenu.'.&Help.&manual\ (utilities)<Tab>'.esc_mapl.'hm        <C-C>:call BASH_help("man")<CR>'
	"
	exe " menu  <silent>  ".s:BASH_RootMenu.'.&Help.-SEP1-                                              :'
	exe " menu  <silent>  ".s:BASH_RootMenu.'.&Help.help\ (Bash-&Support)<Tab>'.esc_mapl.'hbs           :call <SID>HelpPlugin()<CR>'
	exe "imenu  <silent>  ".s:BASH_RootMenu.'.&Help.help\ (Bash-&Support)<Tab>'.esc_mapl.'hbs      <C-C>:call <SID>HelpPlugin()<CR>'
	" }}}2
	"-------------------------------------------------------------------------------

endfunction    " ----------  end of function s:InitMenus  ----------

"-------------------------------------------------------------------------------
" s:CreateAdditionalMaps : Create additional maps.   {{{1
"-------------------------------------------------------------------------------
function! s:CreateAdditionalMaps ()

	"-------------------------------------------------------------------------------
	" Bash dictionary
	"
	" This will enable keyword completion for Bash
	" using Vim's dictionary feature |i_CTRL-X_CTRL-K|.
	"-------------------------------------------------------------------------------
	if exists("g:BASH_Dictionary_File")
		silent! exe 'setlocal dictionary+='.g:BASH_Dictionary_File
	endif

	"-------------------------------------------------------------------------------
	" user defined commands (only working in Bash buffers)
	"-------------------------------------------------------------------------------
	command! -nargs=* -buffer -complete=file -range=0 Bash        call <SID>Run(<q-args>,'c',<line1>,<line2>)

	command! -buffer -nargs=* -complete=file BashScriptArguments  call <SID>ScriptCmdLineArguments(<q-args>)
	command! -buffer -nargs=* -complete=file BashInterpArguments  call <SID>InterpCmdLineArguments(<q-args>)
	command! -buffer -nargs=* -complete=file BashArguments        call <SID>InterpCmdLineArguments(<q-args>)

	"-------------------------------------------------------------------------------
	" settings - local leader
	"-------------------------------------------------------------------------------
	if ! empty ( g:BASH_MapLeader )
		if exists ( 'g:maplocalleader' )
			let ll_save = g:maplocalleader
		endif
		let g:maplocalleader = g:BASH_MapLeader
	endif
	"
	"-------------------------------------------------------------------------------
	" comments
	"-------------------------------------------------------------------------------
	nnoremap  <buffer>  <silent>  <LocalLeader>cl         :call <SID>EndOfLineComment()<CR>
	inoremap  <buffer>  <silent>  <LocalLeader>cl    <C-C>:call <SID>EndOfLineComment()<CR>
	vnoremap  <buffer>  <silent>  <LocalLeader>cl         :call <SID>EndOfLineComment()<CR>
	"
	nnoremap  <buffer>  <silent>  <LocalLeader>cj         :call <SID>AdjustLineEndComm()<CR>
	inoremap  <buffer>  <silent>  <LocalLeader>cj    <C-C>:call <SID>AdjustLineEndComm()<CR>
	vnoremap  <buffer>  <silent>  <LocalLeader>cj         :call <SID>AdjustLineEndComm()<CR>
	"
	nnoremap  <buffer>  <silent>  <LocalLeader>cs         :call <SID>GetLineEndCommCol()<CR>
	inoremap  <buffer>  <silent>  <LocalLeader>cs    <C-C>:call <SID>GetLineEndCommCol()<CR>
	vnoremap  <buffer>  <silent>  <LocalLeader>cs    <C-C>:call <SID>GetLineEndCommCol()<CR>

	nnoremap  <buffer>  <silent>  <LocalLeader>cc         :call <SID>CodeComment()<CR>
	inoremap  <buffer>  <silent>  <LocalLeader>cc    <C-C>:call <SID>CodeComment()<CR>
	vnoremap  <buffer>  <silent>  <LocalLeader>cc         :call <SID>CodeComment()<CR>

	nnoremap  <buffer>  <silent>  <LocalLeader>co         :call <SID>CommentCode(0)<CR>
	inoremap  <buffer>  <silent>  <LocalLeader>co    <C-C>:call <SID>CommentCode(0)<CR>
	vnoremap  <buffer>  <silent>  <LocalLeader>co         :call <SID>CommentCode(0)<CR>

	" :TODO:17.03.2016 12:16:WM: old maps '\cu' for backwards compatibility,
	" deprecate this eventually
	nnoremap  <buffer>  <silent>  <LocalLeader>cu         :call <SID>CommentCode(0)<CR>
	inoremap  <buffer>  <silent>  <LocalLeader>cu    <C-C>:call <SID>CommentCode(0)<CR>
	vnoremap  <buffer>  <silent>  <LocalLeader>cu         :call <SID>CommentCode(0)<CR>

   noremap  <buffer>  <silent>  <LocalLeader>ce         :call <SID>EchoComment()<CR>j'
  inoremap  <buffer>  <silent>  <LocalLeader>ce    <C-C>:call <SID>EchoComment()<CR>j'
   noremap  <buffer>  <silent>  <LocalLeader>cr         :call <SID>RemoveEcho()<CR>j'
  inoremap  <buffer>  <silent>  <LocalLeader>cr    <C-C>:call <SID>RemoveEcho()<CR>j'

	"-------------------------------------------------------------------------------
	" snippets
	"-------------------------------------------------------------------------------

	nnoremap    <buffer>  <silent>  <LocalLeader>nr         :call <SID>CodeSnippet("insert")<CR>
	inoremap    <buffer>  <silent>  <LocalLeader>nr    <Esc>:call <SID>CodeSnippet("insert")<CR>
	nnoremap    <buffer>  <silent>  <LocalLeader>nw         :call <SID>CodeSnippet("create")<CR>
	inoremap    <buffer>  <silent>  <LocalLeader>nw    <Esc>:call <SID>CodeSnippet("create")<CR>
	vnoremap    <buffer>  <silent>  <LocalLeader>nw    <Esc>:call <SID>CodeSnippet("vcreate")<CR>
	nnoremap    <buffer>  <silent>  <LocalLeader>ne         :call <SID>CodeSnippet("edit")<CR>
	inoremap    <buffer>  <silent>  <LocalLeader>ne    <Esc>:call <SID>CodeSnippet("edit")<CR>
	nnoremap    <buffer>  <silent>  <LocalLeader>nv         :call <SID>CodeSnippet("view")<CR>
	inoremap    <buffer>  <silent>  <LocalLeader>nv    <Esc>:call <SID>CodeSnippet("view")<CR>

	"-------------------------------------------------------------------------------
	" run
	"-------------------------------------------------------------------------------
	nnoremap    <buffer>  <silent>  <LocalLeader>rr        :call <SID>Run("","n")<CR>
	inoremap    <buffer>  <silent>  <LocalLeader>rr   <Esc>:call <SID>Run("","n")<CR>
	vnoremap    <buffer>  <silent>  <LocalLeader>rr   <Esc>:call <SID>Run("","v")<CR>
	 noremap    <buffer>  <silent>  <LocalLeader>rc        :call BASH_SyntaxCheck()<CR>
	inoremap    <buffer>  <silent>  <LocalLeader>rc   <C-C>:call BASH_SyntaxCheck()<CR>
	 noremap    <buffer>  <silent>  <LocalLeader>rco       :call BASH_SyntaxCheckOptionsLocal()<CR>
	inoremap    <buffer>  <silent>  <LocalLeader>rco  <C-C>:call BASH_SyntaxCheckOptionsLocal()<CR>
	 noremap    <buffer>            <LocalLeader>ra        :BashScriptArguments<Space>
	inoremap    <buffer>            <LocalLeader>ra   <Esc>:BashScriptArguments<Space>
	 noremap    <buffer>            <LocalLeader>rba       :BashInterpArguments<Space>
	inoremap    <buffer>            <LocalLeader>rba  <Esc>:BashInterpArguments<Space>

	if s:UNIX
		nnoremap    <buffer>  <silent>  <LocalLeader>re        :call <SID>MakeExecutable()<CR>
		inoremap    <buffer>  <silent>  <LocalLeader>re   <C-C>:call <SID>MakeExecutable()<CR>
		vnoremap    <buffer>  <silent>  <LocalLeader>re   <C-C>:call <SID>MakeExecutable()<CR>
	endif

	nnoremap    <buffer>            <LocalLeader>ro         :BashOutputMethod<SPACE>
	inoremap    <buffer>            <LocalLeader>ro    <Esc>:BashOutputMethod<SPACE>
	vnoremap    <buffer>            <LocalLeader>ro    <Esc>:BashOutputMethod<SPACE>
"	nnoremap    <buffer>            <LocalLeader>rd         :BashDirectRun<SPACE>
"	inoremap    <buffer>            <LocalLeader>rd    <Esc>:BashDirectRun<SPACE>
"	vnoremap    <buffer>            <LocalLeader>rd    <Esc>:BashDirectRun<SPACE>
	if index ( s:BASH_OutputMethodList, 'xterm' ) > -1
		nnoremap  <buffer>  <silent>  <LocalLeader>rx         :call <SID>XtermSize()<CR>
		inoremap  <buffer>  <silent>  <LocalLeader>rx    <Esc>:call <SID>XtermSize()<CR>
	endif

	nnoremap    <buffer>  <silent>  <LocalLeader>rh        :call <SID>Hardcopy("n")<CR>
	inoremap    <buffer>  <silent>  <LocalLeader>rh   <C-C>:call <SID>Hardcopy("n")<CR>
	vnoremap    <buffer>  <silent>  <LocalLeader>rh   <C-C>:call <SID>Hardcopy("v")<CR>

   noremap  <buffer>  <silent>  <A-F9>        :call BASH_SyntaxCheck()<CR>
  inoremap  <buffer>  <silent>  <A-F9>   <C-C>:call BASH_SyntaxCheck()<CR>

	if !s:MSWIN
		 noremap  <buffer>  <silent>  <LocalLeader>rd           :call BASH_Debugger()<CR>
		inoremap  <buffer>  <silent>  <LocalLeader>rd      <Esc>:call BASH_Debugger()<CR>
     noremap  <buffer>  <silent>    <F9>                    :call BASH_Debugger()<CR>
    inoremap  <buffer>  <silent>    <F9>               <C-C>:call BASH_Debugger()<CR>
	endif

	"-------------------------------------------------------------------------------
	"   help
	"-------------------------------------------------------------------------------
	nnoremap  <buffer>  <silent>  <LocalLeader>rs         :call BASH_Settings(0)<CR>
  "
   noremap  <buffer>  <silent>  <LocalLeader>hb         :call BASH_help('bash')<CR>
  inoremap  <buffer>  <silent>  <LocalLeader>hb    <Esc>:call BASH_help('bash')<CR>
   noremap  <buffer>  <silent>  <LocalLeader>hh         :call BASH_help('help')<CR>
  inoremap  <buffer>  <silent>  <LocalLeader>hh    <Esc>:call BASH_help('help')<CR>
   noremap  <buffer>  <silent>  <LocalLeader>hm         :call BASH_help('man')<CR>
  inoremap  <buffer>  <silent>  <LocalLeader>hm    <Esc>:call BASH_help('man')<CR>
	 noremap  <buffer>  <silent>  <LocalLeader>hbs        :call <SID>HelpPlugin()<CR>
	inoremap  <buffer>  <silent>  <LocalLeader>hbs   <C-C>:call <SID>HelpPlugin()<CR>

	"-------------------------------------------------------------------------------
	" settings - reset local leader
	"-------------------------------------------------------------------------------
	if ! empty ( g:BASH_MapLeader )
		if exists ( 'll_save' )
			let g:maplocalleader = ll_save
		else
			unlet g:maplocalleader
		endif
	endif

	"-------------------------------------------------------------------------------
	" templates
	"-------------------------------------------------------------------------------
	if s:BASH_Ctrl_j == 'yes'
		nnoremap  <buffer>  <silent>  <C-j>       i<C-R>=<SID>JumpForward()<CR>
		inoremap  <buffer>  <silent>  <C-j>  <C-g>u<C-R>=<SID>JumpForward()<CR>
	endif

	if s:BASH_Ctrl_d == 'yes'
		call mmtemplates#core#CreateMaps ( 'g:BASH_Templates', g:BASH_MapLeader, 'do_special_maps', 'do_del_opt_map' )
	else
		call mmtemplates#core#CreateMaps ( 'g:BASH_Templates', g:BASH_MapLeader, 'do_special_maps' )
	endif

endfunction    " ----------  end of function s:CreateAdditionalMaps  ----------

"===  FUNCTION  ================================================================
"          NAME:  BASH_help     {{{1
"   DESCRIPTION:  lookup word under the cursor or ask
"    PARAMETERS:  -
"       RETURNS:
"===============================================================================
let s:BASH_DocBufferName       = "BASH_HELP"
let s:BASH_DocHelpBufferNumber = -1

let s:BASH_OutputBufferName   = "Bash-Output" " :BUG:28.09.2017 10:41:WM: this is used in BASH_help, check that!

let s:BuiltinList = []

function! BASH_help( type )

	let cuc		= getline(".")[col(".") - 1]		" character under the cursor
	let	item	= expand("<cword>")							" word under the cursor
	if empty(item) || match( item, cuc ) == -1
		if a:type == 'man'
			let item = s:UserInput('[tab compl. on] name of command line utility : ', '', 'shellcmd' )
		endif
		if a:type == 'help'
			let item = s:UserInput('[tab compl. on] name of bash builtin : ', '', 'customlist', s:BuiltinList )
		endif
	endif

	if empty(item) &&  a:type != 'bash'
		return
	endif
	"------------------------------------------------------------------------------
	"  replace buffer content with bash help text
	"------------------------------------------------------------------------------
	"
	" jump to an already open bash help window or create one
	"
	if bufloaded(s:BASH_DocBufferName) != 0 && bufwinnr(s:BASH_DocHelpBufferNumber) != -1
		exe bufwinnr(s:BASH_DocHelpBufferNumber) . "wincmd w"
		" buffer number may have changed, e.g. after a 'save as'
		if bufnr("%") != s:BASH_DocHelpBufferNumber
			let s:BASH_DocHelpBufferNumber=bufnr(s:BASH_OutputBufferName)
			exe ":bn ".s:BASH_DocHelpBufferNumber
		endif
	else
		exe ":new ".s:BASH_DocBufferName
		let s:BASH_DocHelpBufferNumber=bufnr("%")
		setlocal buftype=nofile
		setlocal noswapfile
		setlocal bufhidden=delete
		setlocal syntax=OFF
	endif
	setlocal	modifiable

	" :WORKAROUND:05.04.2016 21:05:WM: setting the filetype changes the global tabstop,
	" handle this manually
	let ts_save = &g:tabstop

	setlocal filetype=man

	let &g:tabstop = ts_save

	"-------------------------------------------------------------------------------
	" read Bash help
	"-------------------------------------------------------------------------------
	if a:type == 'help'
		setlocal wrap
		if s:UNIX 
			silent exe ":%!help -m ".item
		else
			silent exe ":%!".s:BASH_Executable." -c 'help -m ".item."'"
		endif
		setlocal nomodifiable
		return
	endif
	"
	"-------------------------------------------------------------------------------
	" open a manual (utilities)
	"-------------------------------------------------------------------------------
	if a:type == 'man'
		"
		" Is there more than one manual ?
		"
		let manpages	= system( s:BASH_ManualReader.' -k '.item )
		if v:shell_error
			echomsg	"shell command '".s:BASH_ManualReader." -k ".item."' failed"
			:close
			return
		endif
		let	catalogs	= split( manpages, '\n', )
		let	manual		= {}
		"
		" Select manuals where the name exactly matches
		"
		for line in catalogs
			if line =~ '^'.item.'\s\+('
				let	itempart	= split( line, '\s\+' )
				let	catalog		= itempart[1][1:-2]
				let	manual[catalog]	= catalog
			endif
		endfor
		"
		" Build a selection list if there are more than one manual
		"
		let	catalog	= ""
		if len(keys(manual)) > 1
			for key in keys(manual)
				echo ' '.item.'  '.key
			endfor
			let defaultcatalog	= ''
			if has_key( manual, '1' )
				let defaultcatalog	= '1'
			else
				if has_key( manual, '8' )
					let defaultcatalog	= '8'
				endif
			endif
			let	catalog	= input( 'select manual section (<Enter> cancels) : ', defaultcatalog )
			if ! has_key( manual, catalog )
				:close
				:redraw
				echomsg	"no appropriate manual section '".catalog."'"
				return
			endif
		endif
	endif

	"-------------------------------------------------------------------------------
	" open the bash manual
	"-------------------------------------------------------------------------------
	if a:type == 'bash'
		let	catalog	= 1
		let	item		= 'bash'
	endif

	let win_w = winwidth( winnr() )
	if s:UNIX && win_w > 0
			silent exe ":%! MANWIDTH=".win_w." ".s:BASH_ManualReader." ".catalog." ".item
		else
			silent exe ":%!".s:BASH_ManualReader." ".catalog." ".item
		endif

	if s:MSWIN
		call s:bash_RemoveSpecialCharacters()
	endif

	setlocal nomodifiable
endfunction		" ---------- end of function  BASH_help  ----------
"
"===  FUNCTION  ================================================================
"          NAME:  Bash_RemoveSpecialCharacters     {{{1
"   DESCRIPTION:  remove <backspace><any character> in CYGWIN man(1) output
"    PARAMETERS:  -
"       RETURNS:
"===============================================================================
function! s:bash_RemoveSpecialCharacters ( )
	let	patternunderline	= '_\%x08'
	let	patternbold				= '\%x08.'
	setlocal modifiable
	if search(patternunderline) != 0
		silent exe ':%s/'.patternunderline.'//g'
	endif
	if search(patternbold) != 0
		silent exe ':%s/'.patternbold.'//g'
	endif
	setlocal nomodifiable
	silent normal! gg
endfunction		" ---------- end of function  s:bash_RemoveSpecialCharacters   ----------

"===  FUNCTION  ================================================================
"          NAME:  BASH_SyntaxCheckOptions     {{{1
"   DESCRIPTION:  Syntax Check, options
"    PARAMETERS:  -
"       RETURNS:
"===============================================================================
function! BASH_SyntaxCheckOptions( options )
	let startpos=0
	while startpos < strlen( a:options )
		" match option switch ' -O ' or ' +O '
		let startpos		= matchend ( a:options, '\s*[+-]O\s\+', startpos )
		" match option name
		let optionname	= matchstr ( a:options, '\h\w*\s*', startpos )
		" remove trailing whitespaces
		let optionname  = substitute ( optionname, '\s\+$', "", "" )
		" check name
		" increment start position for next search
		let startpos		=  matchend  ( a:options, '\h\w*\s*', startpos )
	endwhile
	return 0
endfunction		" ---------- end of function  BASH_SyntaxCheckOptions----------
"
"===  FUNCTION  ================================================================
"          NAME:  BASH_SyntaxCheckOptionsLocal     {{{1
"   DESCRIPTION:  Syntax Check, local options
"    PARAMETERS:  -
"       RETURNS:
"===============================================================================
function! BASH_SyntaxCheckOptionsLocal ()
	let filename = expand("%")
  if empty(filename)
		redraw
		echohl WarningMsg | echo " no file name or not a shell file " | echohl None
		return
  endif
	let	prompt	= 'syntax check options for "'.filename.'" : '

	if exists("b:BASH_SyntaxCheckOptionsLocal")
		let b:BASH_SyntaxCheckOptionsLocal = s:UserInput( prompt, b:BASH_SyntaxCheckOptionsLocal, '' )
	else
		let b:BASH_SyntaxCheckOptionsLocal = s:UserInput( prompt , "", '' )
	endif

	if BASH_SyntaxCheckOptions( b:BASH_SyntaxCheckOptionsLocal ) != 0
		let b:BASH_SyntaxCheckOptionsLocal	= ""
	endif
endfunction		" ---------- end of function  BASH_SyntaxCheckOptionsLocal  ----------
"
"===  FUNCTION  ================================================================
"          NAME:  BASH_Settings     {{{1
"   DESCRIPTION:  Display plugin settings
"    PARAMETERS:  -
"       RETURNS:
"===============================================================================
function! BASH_Settings ( verbose )

	if     s:MSWIN | let sys_name = 'Windows'
	elseif s:UNIX  | let sys_name = 'UN*X'
	else           | let sys_name = 'unknown' | endif

	let	txt = " Bash-Support settings\n\n"
	" template settings: macros, style, ...
	if exists ( 'g:BASH_Templates' )
		let txt .= '                   author :  "'.mmtemplates#core#ExpandText( g:BASH_Templates, '|AUTHOR|'       )."\"\n"
		let txt .= '                authorref :  "'.mmtemplates#core#ExpandText( g:BASH_Templates, '|AUTHORREF|'    )."\"\n"
		let txt .= '                    email :  "'.mmtemplates#core#ExpandText( g:BASH_Templates, '|EMAIL|'        )."\"\n"
		let txt .= '             organization :  "'.mmtemplates#core#ExpandText( g:BASH_Templates, '|ORGANIZATION|' )."\"\n"
		let txt .= '         copyright holder :  "'.mmtemplates#core#ExpandText( g:BASH_Templates, '|COPYRIGHT|'    )."\"\n"
		let txt .= '                  license :  "'.mmtemplates#core#ExpandText( g:BASH_Templates, '|LICENSE|'      )."\"\n"
		let txt .= '                  project :  "'.mmtemplates#core#ExpandText( g:BASH_Templates, '|PROJECT|'     )."\"\n"
		let txt .= '           template style :  "'.mmtemplates#core#Resource ( g:BASH_Templates, "style" )[0]."\"\n\n"
	else
		let txt .= "                templates :  -not loaded-\n\n"
	endif
	" plug-in installation
	let txt .= '      plugin installation :  '.s:installation.' on '.sys_name."\n"
	let txt .= "\n"
	" templates, snippets
	if exists ( 'g:BASH_Templates' )
		let [ templist, msg ] = mmtemplates#core#Resource ( g:BASH_Templates, 'template_list' )
		let sep  = "\n"."                             "
		let txt .=      "           template files :  "
					\ .join ( templist, sep )."\n"
	else
		let txt .= "           template files :  -not loaded-\n"
	endif
	let txt .=
				\  '       code snippets dir. :  '.s:BASH_CodeSnippets."\n"
	" ----- dictionaries ------------------------
	if !empty(g:BASH_Dictionary_File)
		let ausgabe= &dictionary
		let ausgabe= substitute( ausgabe, ",", ",\n                             ", "g" )
		let txt = txt."       dictionary file(s) :  ".ausgabe."\n"
	endif
	" ----- map leader, menus, file headers -----
	if a:verbose >= 1
		let	txt .= "\n"
					\ .'                mapleader :  "'.g:BASH_MapLeader."\"\n"
					\ .'     load menus / delayed :  "'.s:BASH_LoadMenus.'" / "'.s:BASH_CreateMenusDelayed."\"\n"
					\ .'       insert file header :  "'.s:BASH_InsertFileHeader."\"\n"
	endif
	let txt .= "\n"
	" ----- executables, cmd.-line args, ... -------
	if exists( "b:BASH_InterpCmdLineArgs" )
		let cmd_line_args = b:BASH_InterpCmdLineArgs
	else
		let cmd_line_args = ''
	endif
	if exists("b:BASH_SyntaxCheckOptionsLocal")
		let syn_check_args = b:BASH_SyntaxCheckOptionsLocal
	else
		let syn_check_args = ''
	endif
	let txt .= '          Bash executable :  "'.s:BASH_Executable."\"\n"
	let txt .= ' Bash cmd. line arguments :  "'.cmd_line_args."\"\n"
	let txt .= 'glb. syntax check options :  "'.s:BASH_SyntaxCheckOptionsGlob."\"\n"
	let txt .= 'buf. syntax check options :  "'.syn_check_args."\"\n"
	let txt = txt."\n"
	" ----- output ------------------------------
	let txt = txt.'    current output method :  '.s:BASH_OutputMethod."\n"
	if !s:MSWIN && a:verbose >= 1
		let txt = txt.'         xterm executable :  '.s:Xterm_Executable."\n"
		let txt = txt.'            xterm options :  '.g:Xterm_Options."\n"
	endif
	let	txt = txt."__________________________________________________________________________\n"
	let	txt = txt." Bash-Support, Version ".g:BASH_Version." / Wolfgang Mehner / wolfgang-mehner@web.de\n\n"

	if a:verbose == 2
		split BashSupport_Settings.txt
		put = txt
	else
		echo txt
	endif
endfunction    " ----------  end of function BASH_Settings ----------

"===  FUNCTION  ================================================================
"          NAME:  BASH_SyntaxCheck     {{{1
"   DESCRIPTION:  run syntax check
"    PARAMETERS:  -
"       RETURNS:
"===============================================================================
function! BASH_SyntaxCheck ()

	silent exe 'update'   | " write source file if necessary
	cclose

	" save current settings
	let	makeprg_saved	= &l:makeprg
	let errorf_saved  = &l:errorformat

	let	l:currentbuffer=bufname("%")
	let l:fullname				= expand("%:p")
	"
	" check global syntax check options / reset in case of an error
	if BASH_SyntaxCheckOptions( s:BASH_SyntaxCheckOptionsGlob ) != 0
		let s:BASH_SyntaxCheckOptionsGlob	= ""
	endif
	"
	let	options=s:BASH_SyntaxCheckOptionsGlob
	if exists("b:BASH_SyntaxCheckOptionsLocal")
		let	options=options." ".b:BASH_SyntaxCheckOptionsLocal
	endif
	"
	" match the Bash error messages (quickfix commands)
	" errorformat will be reset by function BASH_Handle()
	" ignore any lines that didn't match one of the patterns

	let &l:makeprg     = s:BASH_Executable
	let &l:errorformat = s:BASH_Errorformat

	silent exe ":make! -n ".options.' -- "'.l:fullname.'"'

	" restore current settings
	let &l:makeprg     = makeprg_saved
	let &l:errorformat = errorf_saved

	botright cwindow

	" message in case of success
	redraw!
	if l:currentbuffer ==  bufname("%")
		echohl Search | echo l:currentbuffer." : Syntax is OK" | echohl None
		nohlsearch						" delete unwanted highlighting (Vim bug?)
	endif
endfunction		" ---------- end of function  BASH_SyntaxCheck  ----------
"
"===  FUNCTION  ================================================================
"          NAME:  BASH_Debugger     {{{1
"   DESCRIPTION:  run debugger
"    PARAMETERS:  -
"       RETURNS:
"===============================================================================
function! BASH_Debugger ()
	if !executable(s:BASH_bashdb)
		echohl Search
		echo   s:BASH_bashdb.' is not executable or not installed! '
		echohl None
		return
	endif
	"
	silent exe	":update"
	let	l:arguments	= exists("b:BASH_ScriptCmdLineArgs") ? " ".b:BASH_ScriptCmdLineArgs : ""
	let	Sou					= fnameescape( expand("%:p") )
	"
	"
	if has("gui_running") || &term == "xterm"
		"
		" debugger is ' bashdb'
		"
		if s:BASH_Debugger == "term"
			let dbcommand	= "!xterm ".g:Xterm_Options.' -e '.s:BASH_bashdb.' -- '.Sou.l:arguments.' &'
			silent exe dbcommand
		endif
		"
		" debugger is 'ddd'
		"
		if s:BASH_Debugger == "ddd"
			if !executable("ddd")
				echohl WarningMsg
				echo "The debugger 'ddd' does not exist or is not executable!"
				echohl None
				return
			else
				silent exe '!ddd --debugger '.s:BASH_bashdb.' '.Sou.l:arguments.' &'
			endif
		endif
	else
		" no GUI : debugger is ' bashdb'
		silent exe '!'.s:BASH_bashdb.' -- '.Sou.l:arguments
	endif
endfunction		" ---------- end of function  BASH_Debugger  ----------

"-------------------------------------------------------------------------------
" s:ToolMenu : Add or remove tool menu entries.   {{{1
"-------------------------------------------------------------------------------
function! s:ToolMenu( action )

	if ! has ( 'menu' )
		return
	endif

	if a:action == 'setup'
		anoremenu <silent> 40.1000 &Tools.-SEP100- :
		anoremenu <silent> 40.1020 &Tools.Load\ Bash\ Support   :call <SID>AddMenus()<CR>
	elseif a:action == 'load'
		aunmenu   <silent> &Tools.Load\ Bash\ Support
		anoremenu <silent> 40.1020 &Tools.Unload\ Bash\ Support :call <SID>RemoveMenus()<CR>
	elseif a:action == 'unload'
		aunmenu   <silent> &Tools.Unload\ Bash\ Support
		anoremenu <silent> 40.1020 &Tools.Load\ Bash\ Support   :call <SID>AddMenus()<CR>
		exe 'aunmenu <silent> '.s:BASH_RootMenu
	endif

endfunction    " ----------  end of function s:ToolMenu  ----------

"-------------------------------------------------------------------------------
" s:AddMenus : Add menus.   {{{1
"-------------------------------------------------------------------------------
function! s:AddMenus()
	if s:MenuVisible == 0
		" the menu is becoming visible
		let s:MenuVisible = 2
		" make sure the templates are loaded
		call s:RereadTemplates ()
		" initialize if not existing
		call s:ToolMenu ( 'load' )
		call s:InitMenus ()
		" the menu is now visible
		let s:MenuVisible = 1
	endif
endfunction    " ----------  end of function s:AddMenus  ----------

"-------------------------------------------------------------------------------
" s:RemoveMenus : Remove menus.   {{{1
"-------------------------------------------------------------------------------
function! s:RemoveMenus()
	if s:MenuVisible == 1
		" destroy if visible
		call s:ToolMenu ( 'unload' )
		" the menu is now invisible
		let s:MenuVisible = 0
	endif
endfunction    " ----------  end of function s:RemoveMenus  ----------

"----------------------------------------------------------------------
" === Setup: Templates and menus ===   {{{1
"----------------------------------------------------------------------

" tool menu entry
call s:ToolMenu ( 'setup' )

if s:BASH_LoadMenus == 'yes' && s:BASH_CreateMenusDelayed == 'no'
	call s:AddMenus ()
endif

" user defined commands (working everywhere)
command! -nargs=? -complete=custom,<SID>GetOutputMethodList BashOutputMethod   call <SID>SetOutputMethod(<q-args>)
command! -nargs=? -complete=custom,<SID>GetDirectRunList    BashDirectRun      call <SID>SetDirectRun(<q-args>)

if has( 'autocmd' )
	"
	"-------------------------------------------------------------------------------
	" shell files with extensions other than 'sh'
	"-------------------------------------------------------------------------------
	if exists( 'g:BASH_AlsoBash' )
		for item in g:BASH_AlsoBash
			exe "autocmd BufNewFile,BufRead  ".item." set filetype=sh"
		endfor
	endif
	"
	"-------------------------------------------------------------------------------
	" create menues and maps
	"-------------------------------------------------------------------------------
  autocmd FileType *
        \ if &filetype == 'sh' |
        \   if ! exists( 'g:BASH_Templates' ) |
        \     if s:BASH_LoadMenus == 'yes' | call s:AddMenus ()  |
        \     else                         | call s:RereadTemplates () |
        \     endif |
        \   endif |
        \   call s:CreateAdditionalMaps () |
				\		call s:CheckTemplatePersonalization() |
        \ endif

	"-------------------------------------------------------------------------------
	" insert file header
	"-------------------------------------------------------------------------------
	if s:BASH_InsertFileHeader == 'yes'
		autocmd BufNewFile  *.sh  call s:InsertFileHeader()
		if exists( 'g:BASH_AlsoBash' )
			for item in g:BASH_AlsoBash
				exe "autocmd BufNewFile ".item." call s:InsertFileHeader()"
			endfor
		endif
	endif

endif
" }}}1
"-------------------------------------------------------------------------------

" =====================================================================================
" vim: tabstop=2 shiftwidth=2 foldmethod=marker
