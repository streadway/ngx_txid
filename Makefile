nginx=nginx-1.3.7
nginx_url=http://nginx.org/download/$(nginx).tar.gz

src=$(wildcard *.c)

test: t/$(nginx)/objs/nginx
	env PATH=$(PWD)/t/$(nginx)/objs:$(PATH) prove5.12 -r t

grind: t/$(nginx)/objs/nginx
	env TEST_NGINX_VERBOSE=1 TEST_NGINX_SLEEP=2 TEST_NGINX_USE_VALGRIND=1 $(MAKE) test

clean:
	rm -f t/$(nginx)/Makefile
	rm -rf t/$(nginx)/objs
	rm -rf t/$(nginx)/.patches-applied

t/$(nginx).tar.gz:
	curl -o $@ $(nginx_url)

t/$(nginx): t/$(nginx).tar.gz
	tar -Ct -xf $<

t/$(nginx)/.patches-applied: t/$(nginx)
	curl https://raw.github.com/shrimp/no-pool-nginx/master/$(nginx)-no_pool.patch | patch -d $< -p1
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

