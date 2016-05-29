all:
	python setup.py build_ext -i

clean:
	rm -r *.so *.c build/
