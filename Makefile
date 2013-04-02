nginx=nginx-1.3.7
nginx_url=http://nginx.org/download/$(nginx).tar.gz

src=$(wildcard *.c)

test: t/$(nginx)/objs/nginx t/ext/lib/perl5
	env PATH=$(PWD)/t/$(nginx)/objs:$(PATH) perl -It/ext/lib/perl5 -MTest::Harness -e "runtests 't/base.t'";

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

t/ext/lib/perl5: t/ext/cpanm
	$< -Lt/ext --notest Test::Nginx Test::Harness
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

