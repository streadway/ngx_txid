nginx=nginx-1.3.7
nginx_url=http://nginx.org/download/$(nginx).tar.gz

libfaketime=libfaketime-0.9.6
libfaketime_url=http://www.code-wizards.com/projects/libfaketime/$(libfaketime).tar.gz

src=$(wildcard *.c)

test: t/$(nginx)/objs/nginx t/ext/lib/perl5 t/ext/$(libfaketime)/src/libfaketime.so.1
	env PATH=$(PWD)/t/$(nginx)/objs:$(PATH) \
		TZ=UTC \
		LD_PRELOAD=$(PWD)/t/ext/$(libfaketime)/src/libfaketime.so.1 \
		DYLD_FORCE_FLAT_NAMESPACE=1 \
		DYLD_INSERT_LIBRARIES=$(PWD)/t/ext/$(libfaketime)/src/libfaketime.1.dylib \
		perl -It/ext/lib/perl5 -MTest::Harness -e "runtests('t/base.t', 't/sortable.t', 't/time_format_past.t', 't/time_format_future.t')";

grind:
	env TEST_NGINX_USE_VALGRIND=1 $(MAKE) test

clean:
	rm -rf t/$(nginx)
	rm -rf t/ext

t/ext:
	mkdir -p $@
	touch $@

t/ext/cpanm: t/ext
	curl -o $@ -L http://cpanmin.us
	chmod +x $@
	touch $@

# Note: Install Test::Nginx from git for new "add_response_body_check"
# functionality used by sortable.t tests. Should go back to CPAN version once
# v0.24 is released.
t/ext/lib/perl5: t/ext/cpanm
	$< -Lt/ext --notest LWP::Protocol::https https://github.com/openresty/test-nginx/archive/daaaa89e98eac58edf233aa1db06fd20b6783886.tar.gz Test::Harness
	touch $@

t/ext/$(libfaketime).tar.gz: t/ext
	curl -o $@ $(libfaketime_url)

t/ext/$(libfaketime): t/ext/$(libfaketime).tar.gz
	tar -Ct/ext -xf $<
	touch $@

t/ext/$(libfaketime)/src/libfaketime.so.1: t/ext/$(libfaketime)
	cd t/ext/$(libfaketime) && $(MAKE)
	touch $@

t/$(nginx).tar.gz:
	curl -o $@ $(nginx_url)

t/$(nginx): t/$(nginx).tar.gz
	tar -Ct -xf $<
	touch $@

t/$(nginx)/.patches-applied: t/$(nginx)
	curl https://raw.github.com/shrimp/no-pool-nginx/master/$(nginx)-no_pool.patch | patch -d $< -p1 --quiet
	perl -p -i -e "s/USR2/XCPU/g" t/$(nginx)/src/core/ngx_config.h # needed for valgrind's USR2 handler
	touch $@

t/$(nginx)/Makefile: t/$(nginx) t/$(nginx)/.patches-applied
	cd t/$(nginx) && ./configure \
		--with-debug \
		--with-cc-opt="-I/usr/local/include" \
		--with-ld-opt="-L/usr/local/lib" \
		--with-ipv6 \
		--add-module=$(PWD) \
		--without-http_charset_module \
		--without-http_userid_module \
		--without-http_auth_basic_module \
		--without-http_autoindex_module \
		--without-http_geo_module \
		--without-http_split_clients_module \
		--without-http_referer_module \
		--without-http_fastcgi_module \
		--without-http_uwsgi_module \
		--without-http_scgi_module \
		--without-http_memcached_module \
		--without-http_limit_conn_module \
		--without-http_limit_req_module \
		--without-http_empty_gif_module \
		--without-http_browser_module \
		--without-http_upstream_ip_hash_module

t/$(nginx)/objs/nginx: t/$(nginx)/Makefile *.c
	$(MAKE) -Ct/$(nginx) -j4 

