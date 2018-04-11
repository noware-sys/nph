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
	local srcdbs srcdbdirs;
	
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

# get all dependent package names of given package names
pkgdepget ()
{
	local deps deps_tmp;
	#local prefix postfix;
	
	deps=();
	deps_tmp=();
	#prefix="${1}";
	#postfix="${2}";
	#shift 2;
	
	for pkg in "${@}"
	do
		if [ ${src_pkg["${pkg}"]} ] && [ -e "${dbdir}/${src_ord[${src_pkg[${pkg}]}]}.d/${pkg}.pkg.dep.txt" ]
		then
			deps=($(grep --extended-regexp --invert-match '^[[:blank:]]*//' "${dbdir}/${src_ord[${src_pkg[${pkg}]}]}.d/${pkg}.pkg.dep.txt" | sed --expression='s/ - .*$//' --expression='s/^[[:blank:]]*//' --expression='s/[[:blank:]]*$//' - | grep --extended-regexp --invert-match --file=- <<< "${deps[@]}"));
			#deps=($(grep --extended-regexp --invert-match '^[[:blank:]]*//' "${dbdir}/${src_ord[${src_pkg_local[${pkg}]}]}.d/${pkg}.pkg.dep.txt" | sed --expression='s/ - .*$//' --expression='s/^[[:blank:]]*//' --expression='s/[[:blank:]]*$//' -));
			# do not add already-present packages
			#deps+=(echo "${deps[@]}" | grep --extended-regexp --invert-match --file=- -);
		fi
	done
	
	# return
	echo "${deps[@]}";
}

# sync dependencies of locally known packages
pkgsrcsyncdep ()
{
	echo '::pkgsrcsyncdepend()::'"${@}";
	#local srcuris="${@}";
	local srcdbdeps srcdbdeps_tmp;
	local i ndx;
	
	srcdbdeps=();
	#srcdbdeps_tmp=();
	
	#for srcname in "${dbdir}/"*'.txt'
	for srcndx in "${!src[@]}"
	do
		#pkgget "${cfgdir}"'/src.db.d/'"${srcndx}"'.db' "${src[${srcndx}]}" ;
		#srcndx=$(echo $(basename "${srcname}") | sed --expression='s/.txt$//' -);
		srcname="${dbdir}/${srcndx}.txt";
		echo '::pkgsrcsyncdepend()::srcndx::'"${srcndx}";
		echo '::pkgsrcsyncdepend()::srcname::'"${srcname}";
		
		srcdbdeps_tmp=($(grep --extended-regexp --invert-match '^[[:blank:]]*//' "${srcname}" | sed --expression='s/ - .*$//' --expression='s/^[[:blank:]]*//' --expression='s/[[:blank:]]*$//' --expression='s|^|'"${src[${srcndx}]}/"'|' --expression='s/$/.pkg.dep.txt/' -));
		
		#for ndx in "${!srcdbdeps_tmp[@]}"
		#do
		#	echo 'srcdbdeps_tmp():key:`'"${ndx}"'`';
		#	echo 'srcdbdeps_tmp():val:`'"${srcdbdeps_tmp[ndx]}"'`';
		#done
		
		#exit 0;
		
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

pkgsrcget ()
{
	local srcs=();
	local prefix postfix;
	local srcname;
	local pkg_present_src;
	
	prefix="${1}";
	postfix="${2}";
	shift 2;
	
	echo "${script_basename}"'::searching which sources have the packages ...';
	for pkg in "${@}"
	do
		if [ $(uriis "${pkg}") == 0 ]
		then
			#srcs+=("${pkg}");
			# save the source where the package was found,
			# in order to get its dependencies from the same source
			pkgname=$(echo $(basename "${pkg}") | sed --expression='s/.pkg.tar$//' -);
			srcuri=$(dirname "${pkg}");
			srcname=$(echo "${srcuri}" | tr '/' '_' -);
			
			if [ ! ${src["${srcname}"]} ]
			then
				echo "${script_basename}"'::error::source '"${src[${srcname}]}"' does not exist';
				exit 1;
			fi
			
			# add only when not present
			if [ ! ${src_pkg["${pkgname}"]} ]
			then
				#src_pkg["${pkgname}"]="${srcuri}";
				
				# temporarily add this source to the `src` and `src_ord` arrays
				src["${srcname}"]="${srcuri}";
				src_ord+=("${srcname}");
				
				src_pkg["${pkgname}"]=((${#src_ord[@]}-1));
				
				# if there is a list of dependencies
				if [ $(curl -o /dev/null --silent --head --write-out '%{http_code}\n' "${srcuri}/${pkgname}.pkg.dep.txt") == 200) ]
				then
					mkdir --parents "${dbdir}/${srcname}.d/";
					# get the list of dependencies
					curl --output "${dbdir}/${srcname}.d/${pkgname}.pkg.dep.txt" "${srcuri}/${pkgname}.pkg.dep.txt";
				fi
			fi
			#src_pkg_local["${pkg}"]='';
		else
			pkgname="${pkg}";
		fi
		
			# add only when not present
			#if [ ! ${src_pkg["${pkgname}"]} ]
			#then
				#srcs+=("${prefix}""${src[0]}/""${pkg}""${postfix}");
				# find the first source that has the package
				# fail the installation if it is not found in any source
				for src_ord_ndx in "${!src_ord[@]}"
				do
					if [ ! ${src[${src_ord[${src_ord_ndx}]}]} ]
					then
						echo "${script_basename}"'::error::source '"${${src_ord[${src_ord_ndx}]}}"' does not exist';
						exit 1;
					elif [ $(curl -o /dev/null --silent --head --write-out '%{http_code}\n' "${src[${src_ord[${src_ord_ndx}]}]}/${pkgname}.pkg.tar") == 200) ]
					then
						pkg_present_src="${src[${src_ord[${src_ord_ndx}]}]}";
						# save the source where the package was found,
						# in order to get its dependencies from the same source
						#src_pkg["${pkg}"]="${src_pkg_present}";
					#	pkg_src["${pkgname}"]="${src_ord_ndx}";
						break;
					fi
				done
				# the end of the array has been reached
				# without a source being found
				if [ ((src_ord_ndx>=${#src_ord{@}})) ]
					echo "${script_basename}"'::error::package '"${pkgname}"' was not found in any source';
					exit 1;
				fi
				
				srcs+=("${prefix}""${pkg_present_src}/""${pkgname}""${postfix}");
			#fi
	done
	unset src_pkg_present;
	
	# return
	echo "${srcs[@]}";
}

# evaluate packages for removal
pkgrmval ()
{
	local pkgs=();
	local prefix postfix;
	
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
		#rm --preserve-root --verbose --recursive --force "${@}";
		#rm --preserve-root --verbose --recursive "${@}";
	#else
	#	echo "${script_basename}"' : '"${@}"' : ''only package <name-ver-arch> should be passed as arguments, not <path/name-ver-arch>';
	#fi
}
