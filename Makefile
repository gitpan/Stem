# Stem makefile for tarring and printing

VERSION		=	0.10

TAR_DIR		=	stem-${VERSION}

TAR_FILE 	=	${TAR_DIR}.tar.gz

all		:
			@echo no target specified

ftp		:	tar
			scp ${TAR_FILE} stemsystems.com:www/

tar		:	co
			mv tarball/stem ${TAR_DIR}
			rmdir tarball
			tar cvfz ${TAR_FILE} --exclude=CVS ${TAR_DIR}

co		:
			/bin/rm -rf tarball ${TAR_DIR}
			mkdir tarball
			cd tarball ; cvs checkout -P stem

faq		:
			cd FAQ; perl faq_maker.pl faq.text

PM		=	$(shell find ${TAR_DIR} -name '*.pm')

#BIN		=	$(shell echo `ls ${TAR_DIR}/bin/* | grep -v proc_serv`)

BIN		=	$(shell perl -e '$$,= " "; \
				print grep -f && -x && !/proc_serv/, \
						@ARGV' ${TAR_DIR}/bin/* )

CONF		=	$(shell find ${TAR_DIR} -name '*.stem)

FILES		=	${PM} ${CONF}

print		:
			trueprint --language=perl -S 2 -2 ${FILES}

echo		:
			@echo ${FILES}

lines		:
			@./util/lines ${PM} ${BIN}

bin_lines	:
			@./util/lines ${BIN}

fix_perl	:
		perl -MConfig -pi -e \
		 's{/usr/local/bin/perl}{$$Config{perlpath}} if $$. == 1' bin/*

uninstall_stem	:	installed_files
			@/bin/rm -f `cat installed_files`

installed_files	:
			@echo "You haven't installed Stem\n"
