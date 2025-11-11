# QtStatic
Static builds of Qt 6

## macOS

```sh
curl -L https://download.qt.io/archive/qt/6.7/6.7.3/single/qt-everywhere-src-6.7.3.tar.xz -o qt.tar.xz
tar xf qt.tar.xz
cd qt-everywhere-src-6.7.3
./configure -static -ltcg -reduce-exports -gc-binaries -submodules qtbase,qtdeclarative,qttools -skip qtlanguageserver,qtquicktimeline -DCMAKE_CXX_FLAGS="-fno-unwind-tables -fomit-frame-pointer -no-pie" -optimize-size -no-feature-icu -release
cmake --build . --parallel
cmake --install . --prefix ../install
cd ../install
tar czf ../qt-6.7.3-macos.tar.gz *
```
