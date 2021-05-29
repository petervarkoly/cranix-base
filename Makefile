#
# Copyright (c) Peter Varkoly Nürnberg, Germany.  All rights reserved.
#
DESTDIR         = /
SHARE           = $(DESTDIR)/usr/share/oss/
FILLUPDIR       = /usr/share/fillup-templates/
PYTHONSITEARCH  = /usr/lib/python3.6/site-packages/
TOPACKAGE       = Makefile addons cups etc plugins python profiles sbin setup salt tools templates updates README.md
HERE            = $(shell pwd)
REPO            = /data1/OSC/home:pvarkoly:OSS-4-1:leap15.1
PACKAGE         = oss-base

install:
	mkdir -p $(SHARE)/{setup,templates,tools,plugins,profiles,updates}
	mkdir -p $(DESTDIR)/usr/sbin/ 
	mkdir -p $(DESTDIR)/$(FILLUPDIR)
	mkdir -p $(DESTDIR)/$(PYTHONSITEARCH)
	mkdir -p $(DESTDIR)/etc/YaST2/
	mkdir -p $(DESTDIR)/usr/lib/systemd/system/
	mkdir -p $(DESTDIR)/srv/salt/_modules/
	mkdir -p $(DESTDIR)/usr/share/cups/
	mkdir -p $(DESTDIR)/usr/lib/rpm/gnupg/keys/
	install -m 644 setup/schoolserver      $(DESTDIR)/$(FILLUPDIR)/sysconfig.schoolserver
	rm -f setup/schoolserver
	install -m 755 sbin/*       $(DESTDIR)/usr/sbin/
	rsync -a   etc/             $(DESTDIR)/etc/
	rsync -a   addons/          $(SHARE)/addons/
	rsync -a   plugins/         $(SHARE)/plugins/
	rsync -a   profiles/        $(SHARE)/profiles/
	rsync -a   setup/           $(SHARE)/setup/
	rsync -a   templates/       $(SHARE)/templates/
	rsync -a   tools/           $(SHARE)/tools/
	if [ -e updates ]; then rsync -a   updates/         $(SHARE)/updates/; fi
	rsync -a   salt/            $(DESTDIR)/srv/salt/
	rsync -a   cups/            $(DESTDIR)/usr/share/cups/
	rsync -a   python/          $(DESTDIR)/$(PYTHONSITEARCH)/cranix/
	mv $(SHARE)/setup/gpg-pubkey-*.asc.key $(DESTDIR)/usr/lib/rpm/gnupg/keys/
	find $(SHARE)/plugins/ $(SHARE)/tools/ -type f -exec chmod 755 {} \;	
	install -m 644 setup/oss-firstboot.xml $(DESTDIR)/etc/YaST2/
	install -m 644 setup/oss_*.service $(DESTDIR)/usr/lib/systemd/system/

dist: 
	xterm -e git log --raw  &
	if [ -e $(PACKAGE) ] ;  then rm -rf $(PACKAGE) ; fi   
	mkdir $(PACKAGE)
	for i in $(TOPACKAGE); do \
	    cp -rp $$i $(PACKAGE); \
	done
	find $(PACKAGE) -type f > files;
	tar jcpf $(PACKAGE).tar.bz2 -T files;
	rm files
	rm -rf $(PACKAGE)
	if [ -d $(REPO)/$(PACKAGE) ] ; then \
	   cd $(REPO)/$(PACKAGE); osc up; cd $(HERE);\
	   mv $(PACKAGE).tar.bz2 $(REPO)/$(PACKAGE); \
	   cd $(REPO)/$(PACKAGE); \
	   osc vc; \
	   osc ci -m "New Build Version"; \
	fi

package:        dist
	rm -rf /usr/src/packages/*
	cd /usr/src/packages; mkdir -p BUILDROOT BUILD SOURCES SPECS SRPMS RPMS RPMS/athlon RPMS/amd64 RPMS/geode RPMS/i686 RPMS/pentium4 RPMS/x86_64 RPMS/ia32e RPMS/i586 RPMS/pentium3 RPMS/i386 RPMS/noarch RPMS/i486
	cp $(PACKAGE).tar.bz2 /usr/src/packages/SOURCES
	rpmbuild -ba $(PACKAGE).spec
	for i in `ls /data1/PACKAGES/rpm/noarch/$(PACKAGE)* 2> /dev/null`; do rm $$i; done
	for i in `ls /data1/PACKAGES/src/$(PACKAGE)* 2> /dev/null`; do rm $$i; done
	cp /usr/src/packages/SRPMS/$(PACKAGE)-*.src.rpm /data1/PACKAGES/src/
	cp /usr/src/packages/RPMS/noarch/$(PACKAGE)-*.noarch.rpm /data1/PACKAGES/rpm/noarch/
	createrepo -p /data1/PACKAGES/

