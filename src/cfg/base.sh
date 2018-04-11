#! /bin/bash

uriis ()
{
	if [ ${#} -lt 1 ]
	then
		echo 2;
	fi
	
	echo "${@}" | grep --silent '://' -;
	echo ${?};
}

#pkgis ()
#{
#	if [ ${#} -lt 1 ]
#	then
#		echo 2;
#	fi
#	
#	echo "${@}" | grep --silent --invert-match '/' -;
#	echo ${?};
#}

array_basename ()
{
	local basenames=();
	local prefix postfix;
	
	prefix="${1}";
	postfix="${2}";
	shift 2;
	
	for var in "${@}"
	do
		if [ $(uriis "${var}") == 0 ]
		then
			basenames+=("${prefix}"$(basename "${var}"));
		else
			basenames+=("${prefix}"$(basename "${var}""${postfix}"));
		fi
	done
	
	# return
	echo "${basenames[@]}";
}

pkgget ()
{
	#XferCommand = /usr/bin/curl -C - --fail %u > %o
	#XferCommand = /usr/bin/curl --max-time 90 -C - -f %u > %o
	#XferCommand = /usr/bin/wget --passive-ftp -c -O %o %u
	
	local destdir;
	
	#currdir="${PWD}";
	destdir="${1}";
	shift 1;
	
	cd "${destdir}";
	#echo "::${PWD}";
	#curl --continue-at - --remote-name-all "${@}";
	curl --remote-name-all "${@}";
	cd -;
	#cd - 1>&/dev/null;
}

pkgsrcsyncdb ()
{
	#echo '::pkgsrcsync()::'"${@}";
	#local srcuris="${@}";
	local srcndx srcdbs srcdbdirs;
	
	srcdbs=();
	srcdbdirs=();
	
	for srcndx in "${!src[@]}"
	do
		#echo '::pkgsrcsyncdb()::'"${srcndx}";
		#pkgget "${cfgdir}"'/src.db.d/'"${srcndx}"'.db' "${src[${srcndx}]}" ;
		
		srcdbs+=('--output');
		srcdbs+=("${dbdir}/${srcndx}.txt");
		#srcdbs+=('--output '"${dbdir}/${srcndx}"'.db');
		srcdbs+=("${src[${srcndx}]}"'/pkg.txt');
		
		srcdbdirs+=("${dbdir}/${srcndx}"'.d');
	done
	echo '::pkgsrcsyncdb::`curl '"${srcdbs[@]}"'`';
	
	#cd "${dbdir}";
	#echo "::${PWD}";
	curl "${srcdbs[@]}";
	#cd -;
	#cd - 1>&/dev/null;
	
	# make all folders for the dependencies for each package
	mkdir --parents "${srcdbdirs[@]}";
}

# sync dependencies of locally known packages
pkgsrcsyncdep ()
{
	echo '::pkgsrcsyncdepend()::'"${@}";
	#local srcuris="${@}";
	local srcndx srcname srcdbdeps srcdbdeps_tmp;
	local i ndx;
	
	srcdbdeps=();
	#srcdbdeps_tmp=();
	
	# for each source
	#for srcname in "${dbdir}/"*'.txt'
	for srcndx in "${!src[@]}"
	do
		#pkgget "${cfgdir}"'/src.db.d/'"${srcndx}"'.db' "${src[${srcndx}]}" ;
		#srcndx=$(echo $(basename "${srcname}") | sed --expression='s/.txt$//' -);
		srcname="${dbdir}/${srcndx}.txt";
		echo '::pkgsrcsyncdepend()::srcndx::'"${srcndx}";
		echo '::pkgsrcsyncdepend()::srcname::'"${srcname}";
		
		srcdbdeps_tmp=($(grep --extended-regexp --invert-match '^[[:blank:]]*//' "${srcname}" | sed --expression='s/ - .*$//' --expression='s/^[[:blank:]]*//' --expression='s/[[:blank:]]*$//' --expression='s|^|'"${src[${srcndx}]}/"'|' --expression='s/$/.dep.txt/' -));
		
		#for ndx in "${!srcdbdeps_tmp[@]}"
		#do
		#	echo 'srcdbdeps_tmp():key:`'"${ndx}"'`';
		#	echo 'srcdbdeps_tmp():val:`'"${srcdbdeps_tmp[ndx]}"'`';
		#done
		
		#exit 0;
		
		# for each package in this source
		for ((i=0; i<${#srcdbdeps_tmp[@]}; ++i))
		do
			srcdbdeps+=('--output');
			srcdbdeps+=("${dbdir}/${srcndx}.d/"$(basename "${srcdbdeps_tmp[${i}]}"));
		done
		srcdbdeps+=(${srcdbdeps_tmp[@]});
	done
	unset srcdbdeps_tmp;
	echo '::pkgsrcsyncdepdend: `curl '"${srcdbdeps[@]}"'`';
	
	#cd "${dbdir}";
	#echo "::${PWD}";
	curl "${srcdbdeps[@]}";
	#cd -;
	#cd - 1>&/dev/null;
}

pkgsrcsyncdepuri ()
{
	#echo '::pkgsrcsync()::'"${@}";
	#local srcuris="${@}";
	local srcdep;
	local pkguri;
	local pkgname;
	local srcname;
	
	srcdep=();
	#srcdbdirs=();
	
	for pkguri in "${@}"
	do
		#echo '::pkgsrcsyncdb()::'"${srcndx}";
		#pkgget "${cfgdir}"'/src.db.d/'"${srcndx}"'.db' "${src[${srcndx}]}" ;
		
		pkgname=$(echo $(basename "${pkguri}") | sed --expression='s/.pkg.tar$//' -);
		srcuri=$(dirname "${pkguri}");
		#srcname=$(echo "${srcuri}" | tr '/' '_' -);
		
		#srcdep+=('--output');
		#srcdep+=("${dbotherdir}/${pkgname}.dep.txt");
		srcdep+=("${srcuri}/${pkgname}.dep.txt");
		
		#srcdbdirs+=("${dbdir}/${srcndx}"'.d');
	done
	echo '::pkgsrcsyncdb::`curl --remote-name-all '"${srcdep[@]}"'`';
	
	cd "${dbotherdir}";
	#echo "::${PWD}";
	curl --remote-name-all "${srcdep[@]}";
	cd -;
	#cd - 1>&/dev/null;
	
	# make all folders for the dependencies for each package
	#mkdir --parents "${srcdbdirs[@]}";
}

pkgsrcget ()
{
	#echo "::pkgsrcget()";
	
	local srcs=();
	local prefix postfix;
	#local srcname;
	local pkgnamefs;
	local src_ord_ndx;
	local src_ord_index_;
	local pkguri;
	local pkg_present_src;
	
	prefix="${1}";
	postfix="${2}";
	shift 2;
	
	#echo "::@ = ${@}";
	
	##echo "${script_basename}::searching which sources have the packages...";
	for pkg in "${@}"
	do
		#echo "::${pkg}";
		if [ $(uriis "${pkg}") == 0 ]
		then
			#echo "uriis";
			#if [ -z $(echo "${pkg}" | cut --delimiter='/' --fields=1 -) ]
			#then
			#	# this is already formatted
			#	# (prepended with a /)
			#	pkguri="${pkg}";
			if echo "${pkg}" | grep --extended-regex --silent '^[^/]*://' -
			then
				# this is a pure protocol
				# it is not already formatted
				# (prepended with a /)
				pkguri="/${pkg}";
			else
				# this is already formatted
				# (prepended with a /)
				pkguri="${pkg}";
			fi
			#pkgname=$(echo $(basename "${pkg}") | sed --expression='s/.pkg.tar$//' -);
		else
			pkgname="${pkg}";
			#echo "pkgname=${pkgname}";
			
			for src_ord_ndx in "${!src_ord[@]}"
			do
				#echo "::src_ord_ndx=${src_ord_ndx}";
				#echo "::src_ord[${src_ord_ndx}]=${src_ord[${src_ord_ndx}]}";
				src_ord_index_="${src_ord[${src_ord_ndx}]}";
				#echo "::src_ord_index_=${src_ord_index_}";
				
				#curl --head --write-out '%{http_code}\n' "${src[${src_ord_index_}]}/${pkgname}.pkg.tar";
				
				if [ ! ${src[${src_ord[${src_ord_ndx}]}]} ]
				then
					##echo "${script_basename}"'::error::source '"{src_ord[${src_ord_ndx}]}"' does not exist';
					exit 1;
				else
					if echo "${src[${src_ord_index_}]}" | grep --extended-regex --silent 'file://' -
					then
						#echo "YES:1";
						pkgnamefs=$(echo "${src[${src_ord_index_}]}" | sed --expression 's|^.*file://||' -);
						
						if [ -e "${pkgnamefs}/${pkgname}.pkg.tar" ]
						then
							pkg_present_src="${src[${src_ord[${src_ord_ndx}]}]}";
							pkguri="${prefix}""${src_ord_ndx}/""${pkg_present_src}/""${pkgname}""${postfix}";
							# save the source where the package was found,
							# in order to get its dependencies from the same source
							##src_pkg["${pkg}"]="${src_pkg_present}";
						#	pkgsrc["${pkguri}"]="${src_ord_ndx}";
							break;
						fi
					else
						#elif [ $(curl --output /dev/null --silent --head --write-out '%{http_code}\n' "${src[${src_ord[${src_ord_ndx}]}]}/${pkgname}.pkg.tar") == 200 ]
						if [ $(curl --output /dev/null --silent --head --write-out '%{http_code}\n' "${src[${src_ord_index_}]}/${pkgname}.pkg.tar") == 200 ]
						then
							#echo "::OK";
							
							pkg_present_src="${src[${src_ord[${src_ord_ndx}]}]}";
							pkguri="${prefix}""${src_ord_ndx}/""${pkg_present_src}/""${pkgname}""${postfix}";
							# save the source where the package was found,
							# in order to get its dependencies from the same source
							##src_pkg["${pkg}"]="${src_pkg_present}";
						#	pkgsrc["${pkguri}"]="${src_ord_ndx}";
							break;
						fi
					fi
				fi
			done
			# the end of the array has been reached
			# without a source being found
			if [ ${src_ord_ndx} -ge ${#src_ord[@]} ]
			then
				##echo "${script_basename}"'::error::package '"${pkgname}"' was not found in any source';
				exit 1;
			fi
		fi
		
		# save the source where the package was found,
		# in order to get its dependencies from the same source
		##src_pkg["${pkg}"]="${src_pkg_present}";
		#pkgsrc["${pkguri}"]="${src_ord_ndx}";
		
		srcs+=("${pkguri}");
	done
	unset src_pkg_present;
	
	# return
	echo "${srcs[@]}";
}

# get all dependent package names of the given package uris
pkgdepget ()
{
	local pkguri deps;
	#local deps_tmp;
	#local prefix postfix;
	local pkgname;
	local pkgsrc;
	
	deps=("${@}");
	#deps=($(echo "${@}" | sed 's|^[^/]*/||' -));
	#deps_tmp=();
	#prefix="${1}";
	#postfix="${2}";
	#shift 2;
	#echo "${deps[@]}";
	#exit 3;
	
	for pkguri in "${@}"
	do
		pkgname=$(echo $(basename "${pkguri}") | sed --expression='s/.pkg.tar$//' -);
		pkgsrc=${src_ord[$(echo "${pkguri}" | cut --delimiter='/' --fields=1 -)]};
		#deps+=("${pkgname}");
		
		#echo ":::${pkgname}";
		#echo ":::${pkguri}";
		##echo ":::${pkgsrc[${pkguri}]}";
		#echo ":::${pkgsrc}";
		##echo ":::${dbdir}/${src_ord[${pkgsrc[${pkguri}]}]}.d/${pkgname}.dep.txt";
		#echo ":::${dbdir}/${pkgsrc}.d/${pkgname}.dep.txt";
		#exit 3;
		if [ -n ${pkgsrc} ]
		then
			#if [ -e "${dbdir}/${src_ord[${pkgsrc[${pkguri}]}]}.d/${pkgname}.dep.txt" ]
			if [ -e "${dbdir}/${pkgsrc}.d/${pkgname}.dep.txt" ]
			then
				#deps+=($(grep --extended-regexp --invert-match '^[[:blank:]]*//' "${dbdir}/${pkgsrc}.d/${pkgname}.dep.txt" | sed --expression='s/ - .*$//' --expression='s/^[[:blank:]]*//' --expression='s/[[:blank:]]*$//' - | grep --extended-regexp --invert-match $(echo "${deps[*]}" | sed -e 's|^.*/||' -e 's|.pkg.tar$||' - | tr ' ' '|') -));
				deps+=($(grep --extended-regexp --invert-match '^[[:blank:]]*//' "${dbdir}/${pkgsrc}.d/${pkgname}.dep.txt" | sed --expression='s/ - .*$//' --expression='s/^[[:blank:]]*//' --expression='s/[[:blank:]]*$//' - | grep --extended-regexp --invert-match $(echo "${deps[*]}" | tr ' ' '\n' | sed -e 's|^.*/||' -e 's|.pkg.tar$||' - | tr '\n' '|' | sed -e 's/|$//'  -) -));
				#deps=($(grep --extended-regexp --invert-match '^[[:blank:]]*//' "${dbdir}/${src_ord[${src_pkg_local[${pkg}]}]}.d/${pkg}.dep.txt" | sed --expression='s/ - .*$//' --expression='s/^[[:blank:]]*//' --expression='s/[[:blank:]]*$//' -));
				# do not add already-present packages
				#deps+=(echo "${deps[@]}" | grep --extended-regexp --invert-match --file=- -);
			fi
		elif [ -e "${dbotherdir}/${pkgname}.dep.txt" ]
		then
			deps+=($(grep --extended-regexp --invert-match '^[[:blank:]]*//' "${dbotherdir}/${pkgname}.dep.txt" | sed --expression='s/ - .*$//' --expression='s/^[[:blank:]]*//' --expression='s/[[:blank:]]*$//' - | grep --extended-regexp --invert-match $(echo "${deps[*]}" | tr ' ' '\n' | sed -e 's|^.*/||' -e 's|.pkg.tar$||' - | tr '\n' '|' | sed -e 's/|$//'  -) -));
		fi
	done
	
	# return
	echo "${deps[@]}";
}

pkggetall ()
{
	local pkguri;
	#local pkguri_expl;
	local pkguri_dep;
	
	#pkguri_expl=("${@}");
	
	# get all remaining dependencies
	pkguri=($(pkgsrcget '' '.pkg.tar' "${@}"));
	pkguri_dep=($(pkgdepget "${pkguri[@]}"));
	#pkguri=($(pkgsrcget '' '.pkg.tar' "${pkguri_dep[@]}"));
	#echo "::norm:${pkguri[*]}";
	#echo "::+dep:${pkguri_dep[*]}";
	#exit 3;
	while [ "${pkguri[*]}" != "${pkguri_dep[*]}" ]
	do
		#echo "In Loop";
		pkguri=($(pkgsrcget '' '.pkg.tar' "${pkguri_dep[@]}"));
		#pkguri=("${pkguri_dep[@]}");
		pkguri_dep=($(pkgdepget "${pkguri[@]}"));
		
		#echo "::norm:${pkguri[*]}";
		#echo "::+dep:${pkguri_dep[*]}";
		#exit 3;
	done
	
	#echo 'RESULT';
	# return
	echo "${pkguri[@]}" | tr ' ' '\n' | sed --expression='s|^[^/]*/*||' -;
}

# evaluate packages for removal
pkgrmval ()
{
	local pkg pkgs;
	local prefix postfix;
	
	pkgs=();
	
	prefix="${1}";
	postfix="${2}";
	shift 2;
	
	for pkg in "${@}"
	do
		pkgs+=("${prefix}""${pkg}""${postfix}");
	done
	
	# return
	echo "${pkgs[@]}";
}

pkginstall ()
{
	#local rootfs="${1}";
	#shift 1;
	
	echo "::install::@ = ${@}";
	#echo "::install::rootfs = ${rootfs}";
	echo "::install::pkgdbdir = ${pkgdbdir}";
	#mkdir --parents "${1}.d/";
	#cat "${@}" | tar xpvf - --xattrs-include='*.*' --numeric-owner --ignore-zeros --directory="${rootfs}";
	cat "${@}" | tar -xpvf - --xattrs-include='*.*' --acls --numeric-owner --ignore-zeros --directory="${pkgdbdir}";
}

pkgremove ()
{
	echo '::pkgremove()::'"${@}";
	#if [ $(pkgis "${@}") == 0 ]
	#then
		echo '::pkgremove()::`rm --preserve-root --verbose --recursive --force '"${@}"'`';
		rm --preserve-root --verbose --recursive --force "${@}";
		#rm --preserve-root --verbose --recursive "${@}";
	#else
	#	echo "${script_basename}"' : '"${@}"' : ''only package <name-ver-arch> should be passed as arguments, not <path/name-ver-arch>';
	#fi
}
