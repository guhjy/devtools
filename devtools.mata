*! vers 0.14.4 14apr2014
*! author: George G. Vega Yon

/* BULID SOURCE_DOC 
Creates source documentation from MATA files
*/

vers 11.0

mata:

/**
 * @brief Runs a stata command and captures the error
 * @param stcmd Stata command
 * @returns Integer _rc
 * @demo
 * /* This is a demo */
 * x = dt_stata_capture(`"di "halo""', 1)
 * x
 * /* Capturing error */
 * x = dt_stata_capture(`"di halo"', 1)
 * x
 */
real scalar function dt_stata_capture(string scalar stcmd, | real scalar noisily) {
	
	real scalar out
	
	/* Running the cmd */
	if (noisily == 1) stata("cap noi "+stcmd)
	else stata("cap "+stcmd)
	
	stata("local tmp=_rc")
	out = strtoreal(st_local("tmp"))
	st_local("tmp","")
	
	return(out)
}

/**
 * @brief Random name generation
 * @param n Char length
 * @demo
 * /* Random name of length 10 */
 * dt_random_name()
 * /* Random name of length 5 */
 * dt_random_name(5)
 */
string scalar function dt_random_name(| real scalar n) {
	
	string scalar output
	string vector letters
	real scalar i
	
	if (n == J(1,1,.)) n = 10
	n = n - 1 
	
	letters = (tokens(c("alpha")), strofreal(0..9))'
	output = "_"
	
	for(i=1;i<=n;i++) output=output+jumble(letters)[1]
	
	return(output)
}

/**
 * @brief Run a shell command and retrive its output
 * @param cmd Shell command to be runned
 * @demo
 * /* Printing on the screen */
 * dt_shell("echo This works!")
 * @demo
 * /* Getting a list of files */
 * dt_shell("dir")
 */
string colvector function dt_shell(string scalar cmd) {
	string scalar tmp, prg
	real scalar i, err
	string colvector out
	
	/* Running the comand */
	tmp = dt_random_name()
	
	if ( (err = dt_stata_capture("shell "+cmd+" > "+tmp)) )
		_error(err, "Couldn't complete the operation")
	
	out = dt_read_txt(tmp)
	unlink(tmp)
	return(out)
}

/**
 * @brief Erase using OS
 */
void function dt_erase_file(string scalar fns, | string scalar out, real scalar sh) {
	
	string scalar cmd, prg

	if (sh == 1) prg = "shell"
	else prg = "winexec"
	
	if (c("OS") == "Windows") cmd = "winexec erase /F "+fns
	else cmd = "winexec rm -f "+fns
	
	if (args()>1) out = cmd
	else stata(cmd)
	
	return
}

/**
 * @brief Copy using OS
 * @param fn1 Original file
 * @param fn2 New filename
 * @param out Optional, if specified then the cmd is not executed, rather it stores it at -out-
 * @returns A force copy from -fn1- to -fn2-
 */
void function dt_copy_file(string scalar fn1, string scalar fn2, | string scalar out, real scalar sh) {

	string scalar cmd, prg

	if (sh == 1) prg = "shell"
	else prg = "winexec"

	if (c("OS") == "Windows") cmd = prg+" copy /Y "+fn1+" "+fn2
	else cmd = prg+" cp -f "+fn1+" "+fn2
	
	if (args()>2) out = cmd
	else stata(cmd)
	
	return
}

 
/**
 * @brief Restarts stata
 * @param cmd Comand to execute after restarting stata
 * @returns Restarts stata, loads data and executes -cmd-
 */
void function dt_restart_stata(| string scalar cmd, real scalar ext) {

	real scalar fh
	real scalar isdta, ismata
	string scalar tmpcmd
	
	/* Checking if a dataset is loaded */
	if ( (isdta = c("N") | c("k")) )
	{
		string scalar tmpdta, dtaname
		dtaname = c("filename")
		tmpdta = dt_random_name()+".dta"
		stata("save "+tmpdta+", replace")
	}
	
	/* Checking if profile file already exists */
	real scalar isprofile
	isprofile = fileexists("profile.do")
	
	string scalar tmpprofile
	tmpprofile=dt_random_name()+".do"
	
	if (isprofile)
	{
		dt_copy_file("profile.do", tmpprofile)
		fh = fopen("profile.do","a")
	}
	else fh = fopen("profile.do","w")
	
	if (isdta) fput(fh, "use "+tmpdta+", clear")
	/* if (ismat) fput( */
	
	if (cmd != J(1,1,"")) fput(fh, cmd)
	
	/* Operations to occur right after loading the data*/
	if (isprofile)
	{	
		dt_copy_file(tmpprofile, "profile.do", tmpcmd)
		fput(fh, tmpcmd)
		fput(fh, "erase "+tmpprofile)
	}
	else 
	{
		dt_erase_file("profile.do", tmpcmd)
		fput(fh, tmpcmd)
	}
	
	/* Modifying data */
	if (isdta)
	{
		fput(fh, "erase "+tmpdta)
		fput(fh, "global S_FN ="+dtaname)
	}
	
	fclose(fh)
	
	if (ext==J(1,1,.)) ext=1
	
	string scalar statapath
	statapath = dt_stata_path(1)
	
	if (!dt_stata_capture("winexec "+statapath))
	{
		if (ext) stata("exit, clear")
	}
	else 
	{
		if (isprofile)
		{
			dt_copy_file(tmpprofile,"profile.do")
			unlink(tmpprofile)
		}
		else dt_erase_file("profile.do")
		if (isdta) unlink(tmpdta)
	}
	return
}

/**
 * @brief Builds a help file from a MATA source file.
 * @param fns A List of mata files.
 * @param output Name of the resulting file
 * @param replace Whether to replace or not a hlp file.
 * @returns A nice help file showing source code.
 */
void dt_moxygen(
	string vector fns,
	string scalar output,
	| real scalar replace)
{
	
	/* Setup */
	real scalar i, j, fh_input, fh_output
	string scalar fn, line, funname
	string scalar regexp_fun_head, rxp_oxy_brief, rxp_oxy_param, rxp_oxy_returns, rxp_oxy_auth, oxy
	string scalar rxp_oxy_demo
	string vector eltype_list, orgtype_list
	
	string scalar tab
	tab = "([\s ]|"+sprintf("\t")+")*"
	
	////////////////////////////////////////////////////////////////////////////////
	/* Building regexp for match functions headers */
	// mata
	eltype_list  = "transmorphic", "numeric", "real", "complex", "string", "pointer"
	orgtype_list = "matrix", "vector", "rowvector", "colvector", "scalar"
	
	/* Every single combination */
	regexp_fun_head = "^"+tab+"(void|"
	for(i=1;i<=length(eltype_list);i++)
		for(j=1;j<=length(orgtype_list);j++)
			regexp_fun_head = regexp_fun_head+eltype_list[i]+"[\s ]+"+orgtype_list[j]+"|"
	
	/* Single element */
	for(i=1;i<=length(eltype_list);i++)
		regexp_fun_head = regexp_fun_head+eltype_list[i]+"|"
	
	for(i=1;i<=length(orgtype_list);i++)
		if(i!=length(orgtype_list)) regexp_fun_head = regexp_fun_head+orgtype_list[i]+"|"
		else regexp_fun_head = regexp_fun_head+orgtype_list[i]+")[\s ]*(function)?[\s ]+([a-zA-Z0-9_]+)[(]"
	
	/* MATA oxygen */
	rxp_oxy_brief   = "^"+tab+"[*][\s ]*@brief[\s ]+(.*)"
	rxp_oxy_param   = "^"+tab+"[*][\s ]*@param[\s ]+([a-zA-Z0-9_]+)[\s ]*(.*)"	
	rxp_oxy_returns = "^"+tab+"[*][\s ]*@(returns?|results?)[\s ]*(.*)"
	rxp_oxy_auth    = "^"+tab+"[*][\s ]*@authors?[\s ]+(.*)"
	rxp_oxy_demo = "^"+tab+"[*][\s ]*@demo(.*)"

	/*if (regexm("void build_source_doc(", regexp_fun_head))
		regexs(1), regexs(3)
	regexp_fun_head
	
	end*/
	
	////////////////////////////////////////////////////////////////////////////////
	if (replace == J(1,1,.)) replace = 1
	
	/* Checks if the file has to be replaced */
	if (!regexm(output, "[.]hlp$|[.]sthlp$")) output = output + ".sthlp"
	if (fileexists(output) & !replace)
	{
		errprintf("File -%s- already exists. Set -replace- option to 1.", output)
		exit(0)
	}
	
	/* Starting the hlp file */
	if (fileexists(output)) unlink(output)
	fh_output = fopen(output, "w", 1)
	
	/* Looping over files */
	for(i=1;i<=length(fns);i++)
	{
		/* Picking the ith filename */
		fn = fns[i]
		
		/* If it exists */
		if (fileexists(fn))
		{
			/* Opening the file */
			fh_input = fopen(fn, "r")
			
			/* Header of the file */
			fput(fh_output, "*! {smcl}")
			fput(fh_output, "*! {c TLC}{dup 78:{c -}}{c TRC}")
			fput(fh_output, "*! {c |} {bf:Beginning of file -"+fn+"-}{col 83}{c |}")
			fput(fh_output, "*! {c BLC}{dup 78:{c -}}{c BRC}")
			
			oxy = ""
			real scalar nparams, inOxygen, nauthors, inDemo, nDemos
			string scalar demostr, demoline
			nparams  = 0
			nauthors = 0
			inOxygen = 0
			inDemo   = 0
			demostr  = ""
			demoline = ""
			nDemos   = 0
			while((line = fget(fh_input)) != J(0,0,""))
			{
				/* MATAoxygen */
				if (regexm(line, "^"+tab+"[/][*]([*]|[!])(d?oxygen)?"+tab+"$") | inOxygen) {
				
					if (regexm(line, "^"+tab+"[*][/]"+tab+"$") & !inDemo)
					{
						inOxygen = 0
						continue
					}
					
					/* Incrementing the number of oxygen lines */
					if (!inOxygen++) line = fget(fh_input)
					
					if (regexm(line, rxp_oxy_brief))
					{
						oxy = sprintf("\n*!{dup 78:{c -}}\n*!{col 4}{it:%s}",regexs(2))
						continue
					}
					if (regexm(line, rxp_oxy_auth))
					{
						if (!nauthors++) oxy = oxy+sprintf("\n*!{col 4}{bf:author(s):}")
						oxy = oxy+sprintf("\n*!{col 6}{it:%s}",regexs(2))
						continue
					}
					if (regexm(line, rxp_oxy_param))
					{
						if (!nparams++) oxy = oxy+sprintf("\n*!{col 4}{bf:parameters:}")
						oxy = oxy+sprintf("\n*!{col 6}{bf:%s}{col 20}%s",regexs(2),regexs(3))
						continue
					}
					if (regexm(line, rxp_oxy_returns))
					{
						oxy = oxy+sprintf("\n*!{col 4}{bf:%s:}\n*!{col 6}{it:%s}", regexs(2), regexs(3))
						continue
					}
					if (regexm(line, rxp_oxy_demo) | inDemo)
					{
						string scalar democmd
						
						/* Checking if it ended with another oxy object */
						if ((regexm(line, rxp_oxy_demo) & inDemo) | regexm(line, "^"+tab+"@") | regexm(line, "^"+tab+"[*][/]"+tab+"$")) 
						{
							
							oxy      = oxy + sprintf("\n%s\n%s dt_enddem():({it:click to run})}\n",demostr,demoline)
							demostr  = ""
							demoline = ""
							inDemo   = 0
							
						}
									
						/* When it first enters */
						if (regexm(line, rxp_oxy_demo) & !inDemo)
						{
							demoline = "{matacmd dt_inidem();"
							demostr  = ""
							inDemo   = 1
							nDemos   = nDemos + 1
							
							oxy = oxy + sprintf("\n*!{col 4}{bf:Demo %g}", nDemos)
							continue
						}
						
						democmd = sprintf("%s", regexr(line,"^"+tab+"[*]",""))
						
						if (!regexm(democmd,"^"+tab+"/[*](.*)[*]/")) demoline = demoline+democmd+";"
						demostr  = demostr+sprintf("\n%s",democmd)
						continue
					}
				}
				/* Checking if it is a function header */
				if (regexm(line, regexp_fun_head)) 
				{
					funname = regexs(4)
					
					fput(fh_output, "{smcl}")
					fput(fh_output, "*! {marker "+funname+"}{bf:function -{it:"+funname+"}- in file -{it:"+fn+"}-}")
					fwrite(fh_output, "*! {back:{it:(previous page)}}")
					
//					printf("{help %s##%s:%s}", regexr(output, "[.]sthlp$|[.]hlp$", ""), funname, funname)
					if (oxy!="") {
						fwrite(fh_output, oxy)
						oxy      = ""
						nparams  = 0
						nauthors = 0
						inOxygen = 0
						nDemos   = 0
					}
					fput(fh_output,sprintf("\n*!{dup 78:{c -}}{asis}"))
				}
				fput(fh_output, subinstr(line, char(9), "    "))
 
			}
						
			fclose(fh_input)
			
			/* Footer of the file */
			fput(fh_output, "*! {smcl}")
			fput(fh_output, "*! {c TLC}{dup 78:{c -}}{c TRC}")
			fput(fh_output, "*! {c |} {bf:End of file -"+fn+"-}{col 83}{c |}")
			fput(fh_output, "*! {c BLC}{dup 78:{c -}}{c BRC}")
			
			continue
		}
		
		/* If it does not exists */
		printf("File -%s- doesn't exists\n", fn)
		continue
				
	}
	
	fclose(fh_output)
}

/**
 * @brief Begins a demo
 */
void function dt_inidem(|string scalar demoname, real scalar preserve) {
	if (args() < 2 | preserve == 1) stata("preserve")
	display("{txt}{hline 2} begin demo {hline}")
	display("")
	return
}

/**
 * @brief Ends a demo
 */
void function dt_enddem(| real scalar preserve) {
	if (args() < 1 | preserve == 1) stata("restore")
	display("")
	display("{txt}{hline 2} end demo {hline}")
	return
}

/**
 * @brief Recursive highlighting for mata.
 * @param line String to highlight.
 * @returns A highlighted text (to use with display)
 * @demo
 * txt = dt_highlight(`"build(1+1-less(h)- signa("hola") + 1 - insert("chao"))"')
 * txt
 * display(txt)
 */
string scalar dt_highlight(string scalar line) {
	string scalar frac, newline
	real scalar test
	
	string scalar regexfun, regexstr
	regexfun = "^(.+[+]|.+[*]|.+-|.+/|)?[\s ]*([a-zA-Z0-9_]+)([(].+)"
	regexstr = `"^(.+)?(["][a-zA-Z0-9_]+["])(.+)"'
	
	test = 1
	newline =""
	/* Parsing functions */
	while (test)
	{
		if (regexm(line, regexfun))
		{
			frac = regexs(2)
			newline = sprintf("{bf:%s}",frac) + regexs(3)+newline
			line = subinstr(line, frac+regexs(3), "", 1)
		}
		else test = 0
	}

	test = 1
	line = line+newline
	newline =""
	/* Parsing strings */
	while (test)
	{
		if (regexm(line, regexstr))
		{
			frac = regexs(2)
			newline = sprintf("{it:%s}",frac)+ regexs(3) + newline 
			line = subinstr(line, frac+regexs(3), "", 1)
		}
		else test = 0
		
	}
		
	return("{text:"+line+newline+"}")
}

/**
 * @brief Split a text into many lines
 * @param txt Text to analize (and split)
 * @param n Max line width
 * @param s Indenting for the next lines
 * @returns A text splitted into several lines.
 * @demo
 * printf(dt_txt_split("There was this little fella who once jumped into the water...\n", 10, 2))
 * @demo
 * printf(dt_txt_split("There was this little fella who once jumped into the water...\n", 15, 4))
 */
string scalar function dt_txt_split(string scalar txt, | real scalar n, real scalar indent) {

	string scalar newtxt, sindent
	real scalar curn, i

	if (n==J(1,1,.))
	{
		n = 80
		indent = 0
	}
	
	/* Creating the lines indenting */
	sindent = ""
	for(i=0;i<indent;i++) sindent = sindent + " "
	
	i = 0
	if ((curn = strlen(txt)) > n)
		while ((curn=strlen(txt)) > 0) {
			
			if (!i++) newtxt = substr(txt,1,n)
			else newtxt = newtxt + sprintf("\n"+sindent) + substr(txt,1,n)
			txt = substr(txt,n+1)
			
		}
		
	return(newtxt)
}

/**
 * @brief Builds a temp source help
 * @param fns A vector of file names to be parsed for Mata oxygen.
 * @param output Name of the output file.
 * @param replace Whether to replace the file or not.
 * @returns a hlp file (and a view of it).
 */
void function dt_moxygen_preview(| string vector fns, string scalar output, real scalar replace) {

	/* Filling emptyness */
	if (fns == J(1, 0, ""))  fns = dir(".","files","*.mata")
	if (output == J(1,1,"")) {
		output  = st_tempfilename()
		replace = 1
	}
	
	/* Building and viewing */
	dt_moxygen(fns, output, replace)
	
	stata("view "+output)
	
	return
	
}

/** 
 * @brief Install a stata module on the fly
 * @param fns A list of the files that should be installed
 * @returns 
 */
void function dt_install_on_the_fly(|string scalar pkgname, string scalar fns, string scalar pkgdir) {

	string scalar olddir
	olddir = c("pwd")
	if (args() < 3) pkgdir = c("pwd")

	if (dt_stata_capture("cd "+pkgdir))
		_error(1, "Couldn't find the -"+pkgdir+"- dir")

	if (fns==J(1,1,"")) fns = dir(".","files","*.mlib")\dir(".","files","*.ado")\dir(".","files","*.sthlp")\dir(".","files","*.hlp")
	
	if (!length(fns)) return
	
	real scalar fh, i
	string scalar fn, toc, tmpdir

	if (!regexm(tmpdir = c("tmpdir"),"([/]|[\])$")) 
		tmpdir = tmpdir+"/"
	tmpdir
	if (pkgname == J(1,1,"")) pkgname = "__mytmppgk"
	
	/* Creating tmp toc */
	if (fileexists(tmpdir+"stata.toc")) unlink(tmpdir+"stata.toc")
	fh = fopen(tmpdir+"stata.toc","w")
	fput(fh, sprintf("v0\ndseveral packages\n")+"p "+pkgname)
	fclose(fh)
	
	/* Creating the pkg file */
	unlink(tmpdir+pkgname+".pkg")
	if (fileexists(pkgname+".pkg")) /* if the package file exists, there is no need to build it!*/
	{
		dt_copy_file(pkgname, tmpdir+pkgname)
		for(i=1;i<=length(fns);i++)
		{
			display("copy "+fns[i]+" "+tmpdir+fns[i])
			if (dt_stata_capture("copy "+fns[i]+" "+tmpdir+fns[i]+", replace"))
			{
				fclose(fh)
				unlink(tmpdir+"stata.toc")
				_error("Can't continue: Error while copying the file "+fns[i])
			}			
		}
	}
	else
	{
		fh = fopen(tmpdir+pkgname+".pkg","w")
		
		fput(fh, "v 3")
		fput(fh, "d "+pkgname+" A package created by -devtools-.")
		fput(fh, "d Distribution-Date:"+sprintf("%tdCYND",date(c("current_date"),"DMY")))
		fput(fh, "d Author: "+c("username"))
		for(i=1;i<=length(fns);i++)
		{
			display("copy "+fns[i]+" "+tmpdir+fns[i])
			if (dt_stata_capture("copy "+fns[i]+" "+tmpdir+fns[i]+", replace"))
			{
				fclose(fh)
				unlink(tmpdir+"stata.toc")
				_error("Can't continue: Error while copying the file "+fns[i])
			}
			
			fput(fh,"F "+fns[i])
		}
		
		fclose(fh)
	}
	/* Installing the package */
	stata("cap ado unistall "+pkgname)
	
	real scalar cap
	if (cap=dt_stata_capture("net install "+pkgname+", from("+tmpdir+") force replace"))
	{
		unlink(tmpdir+"stata.toc")
		for(i=1;i<=length(fns);i++)
			unlink(tmpdir+fns[i])
		
		_error(cap,"An error has occurred while installing.")
	}

	stata("mata mata mlib index")
	
	/*
	/* Restarting dataset */
	if (c("N") | c("k")) 
	{
		if (c("os") != "Windows") 
		{ // MACOS/UNIX
			unlink("__pll"+parallelid+"_shell.sh")
			fh = fopen("__pll"+parallelid+"_shell.sh","w", 1)
			// fput(fh, "echo Stata instances PID:")
			
			// Writing file
			if (c("os") != "Unix") 
			{
				for(i=1;i<=nclusters;i++) 
					fput(fh, paralleldir+" -e do __pll"+parallelid+"_do"+strofreal(i)+".do &")
			}
			else 
			{
				for(i=1;i<=nclusters;i++) 
					fput(fh, paralleldir+" -b do __pll"+parallelid+"_do"+strofreal(i)+".do &")
			}
			
			fclose(fh)
			
			// stata("shell sh __pll"+parallelid+"shell.sh&")
			stata("winexec sh __pll"+parallelid+"_shell.sh")
		}
		else 
		{ // WINDOWS
			for(i=1;i<=nclusters;i++) 
			{
				// Lunching procces
				stata("winexec "+paralleldir+" /e /q do __pll"+parallelid+"_do"+strofreal(i)+".do ")
			}
		}
	}*/

	stata("cap cd "+olddir)
	display("Package -"+pkgname+"- correctly installed")
	
	return
}

/**
 * @brief Looks up for a regex within a list of plain text files
 * @param regex Regex to lookup for
 * @param fixed Whether to interpret the regex arg as a regex or not (1: Not, 0: Yes)
 * @param fns List of files to look in (default is to take all .do .ado .hlp .sthlp and .mata)
 * @returns Coordinates (line:file) where the regex was found 
 */
void dt_lookuptxt(string scalar pattern , | real scalar fixed, string colvector fns) {
	
	if (!length(fns)) fns = dir(".","files","*.do")\dir(".","files","*.ado")\dir(".","files","*.mata")
	
	if (!length(fns)) return
	
	real scalar fh, nfs, i ,j
	string scalar line
	
	nfs = length(fns)
		
	for(i=1;i<=nfs;i++)
	{
		// printf("Revisando archivo %s\n",fns[i])
		fh = fopen(fns[i],"r")
		j=0
		while((line=fget(fh)) != J(0,0,"")) {
			j = j+1

			if (fixed)
			{
				if (strmatch(line,"*"+pattern+"*"))
					printf("In line %g on file %s\n", j, fns[i])
			}
			else
			{
				if (regexm(line, pattern))
					printf("In line %g on file %s\n", j,fns[i])
			}
		}

		fclose(fh)
	}

}

/**
 * @brief Uninstall all versions of a certain package
 * @param pkgname Name of the package
 * @returns Nothing
 */
void dt_uninstall_pkg(string scalar pkgname) {

	string scalar pkgs
	string scalar logname, regex, line, tmppkg
	real scalar fh, counter

	counter = 0
	logname = st_tempfilename()
	while (counter >= 0)
	{
		/* Listing files */
		stata("log using "+logname+", replace text")
		stata("ado dir "+pkgname)
		stata("log close")

		/* Looking for pkgs and removing them */
		fh = fopen(logname, "r")

		regex = "^[ ]*([[][0-9]+[]]) package "+pkgname
		counter = 0
		while((line=fget(fh)) != J(0,0,"")) 
		{
			/* If the package matched, then remove it */
			if (regexm(line, regex)) 
			{
				tmppkg = regexs(1)
				display("Will remove the package "+tmppkg+" ("+pkgname+")")
				if (dt_stata_capture("ado uninstall "+tmppkg)) continue
				else counter = counter + 1
			}
		}

		fclose(fh)
		unlink(logname)
		
		if (counter == 0) counter = -1
		else counter = 0
	}
	return
}

/**
 * @brief Reads a txt file (fast).
 * @param fn File name.
 * @param newline New line sep.
 * @returns A colvector of length = N of lines.
 */
string colvector function dt_read_txt(
	string scalar fn,
	| string scalar newline,
	real scalar buffsize
	)
{
	real scalar fh
	string matrix EOF
	string scalar txt, txttmp
	string colvector fhv
	
	if (buffsize == J(1,1,.)) buffsize = 1024*1024
	else if (buffsize > 1024*1024)
	{
		buffsize = 1024*1024
		display("Max allowed buffsize : 1024*1024")
	}
	
	if (newline == J(1,1,"")) newline = sprintf("\n")
	else newline = sprintf(newline)
	EOF = J(0,0,"")
	
	fh = fopen(fn,"r")
	txttmp = ""
	while((txt=fread(fh,buffsize)) != EOF) txttmp = txttmp+txt
	fclose(fh)
	
	fhv = tokens(txttmp,newline)'
	fhv = select(fhv, fhv:!=newline)
	
	return(fhv)
}

/**
 * @brief Builds stata exe path
 * @returns Stata exe path
 * @demo
 * dt_stata_path()
 */
string scalar dt_stata_path(|real scalar xstata) {

	string scalar bit, flv
	string scalar statadir
	if (xstata==J(1,1,.)) xstata=0

	// Is it 64bits?
	if (c("osdtl") != "" | c("bit") == 64) bit = "-64"
	else bit = ""
	
	// Building fullpath name
	string scalar sxstata
	sxstata = (xstata ? "x" : "")

	if (c("os") == "Windows") { // WINDOWS
		if (c("MP")) flv = "MP"
		else if (c("SE")) flv = "SE"
		else if (c("flavor") == "Small") flv = "SM"
		else if (c("flavor") == "IC") flv = ""
	
		/* If the version is less than eleven */
		if (c("stata_version") < 11) statadir = c("sysdir_stata")+"w"+flv+"Stata.exe"
		else statadir = c("sysdir_stata")+"Stata"+flv+bit+".exe"

	}
	else if (regexm(c("os"), "^MacOS.*")) { // MACOS
	
		if (c("stata_version") < 11 & (c("osdtl") != "" | c("bit") == 64)) bit = "64"
		else bit = ""
	
		if (c("MP")) flv = "Stata"+bit+"MP" 
		else if (c("SE")) flv = "Stata"+bit+"SE"
		else if (c("flavor") == "Small") flv = "smStata"
		else if (c("flavor") == "IC") flv = "Stata"+bit
		
		statadir = c("sysdir_stata")+flv+".app/Contents/MacOS/"+sxstata+flv
	}
	else { // UNIX
		if (c("MP")) flv = "stata-mp" 
		else if (c("SE")) flv = "stata-se"
		else if (c("flavor") == "Small") flv = "stata-sm"
		else if (c("flavor") == "IC") flv = "stata"
	
		statadir = c("sysdir_stata")+sxstata+flv
	}

	if (!regexm(statadir, `"^["]"')) return(`"""'+statadir+`"""')
	else return( statadir )
}

/**
 * @brief Install a module from a git repo
 * @param pkgname Name of the package (repo)
 * @param usr Name of the repo owner
 * @param which Whether to install it from github, bitbucket or googlecode
 */
void dt_git_install(string scalar pkgname, string scalar usr, | string scalar which) {

	string colvector valid_repos, out
	string scalar uri
	valid_repos = ("github","bitbucket","googlecode")
	
	/* Checking which version */
	if (which == J(1,1,"")) which = "github"
	else if (!length(select(valid_repos,valid_repos:==which)))
		_error(1,"Invalid repo, try using -github-, -bitbucket- or -googlecode-")

	/* Checking git */
	out = dt_shell("git --version")
	if (!length(out)) 
		_error(1, "Git is not install in your OS.")
	else if (!regexm(out[1,1],"^git version"))
		_error(1, "Git is not install in your OS.")
			
	/* Check if git is */
	if (which=="github") uri = sprintf("https://github.com/%s/%s.git", usr, pkgname)

	out = dt_shell("git clone "+uri+" "+c("tmpdir")+"/"+pkgname)
	if (regexm(out[1,1],"^(e|E)rror"))
	{
		out
		_error(1,"Could connect to git repo")
	}

	dt_install_on_the_fly(pkgname,J(1,1,""),c("tmpdir")+"/"+pkgname)

	return
	
}
 
/**
 * @brief recursively list files
 * @param pattern File pattern such as '*mlib *ado'
 * @param regex (Unix systems only) 1 to specify that the pattern is a regex
 * @returns a list of files with their full path names
 * @demo
 * /* List of all the files */
 * dt_list_files()
 * @demo
 * /* List of ado files */
 * dt_list_files("*ado")
 */
string colvector function dt_list_files(|string scalar pattern, real scalar regex)
{
	string colvector files
	real scalar nfiles,i
	if (c("os")=="Windows")	
	{
		/* Retrieving the files from windows */
		files = dt_shell("dir /S /B "+pattern)
		nfiles=length(files)
		
		/* Removing trailing return */
		for(i=1;i<=nfiles;i++)
			files[i] = subinstr(files[i],sprintf("\r"),"")
			
	}
	else
	{
		/* Retrieving the files from Unix */
		if (strlen(pattern))
		{
			/* Preparing regex */
			if (args() < 2 | regex == 1)
			{
				pattern = subinstr(pattern,"*","",.)
				pattern = subinstr(pattern,".","\.",.)
				pattern = ".+("+subinstr(stritrim(strtrim(pattern))," ","|")+")$"
			}
			files = dt_shell("find . | grep -E '"+pattern+"'")
		}
		else files = dt_shell("find .")
		
		nfiles = length(files)
		
		/* Replacing dots */
		for(i=1;i<=nfiles;i++)
			files[i] = regexr(files[i],"^\.",c("pwd"))
		
	}
	return(files)
}

end
