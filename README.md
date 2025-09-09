# GPU_Cache_Size_Apple_Silicon

Finding cache line size (in bytes) for Apple Silicon GPU with cache access latency using Swift &amp; Metal code (MacOS App)



Xcode is prerequisite 

To run via command line, install command line tools for Xcode:
```
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
```


To Build:

```
xcodebuild -scheme GPUCacheSizeTest -derivedDataPath build
```

To run:

```
./build/Build/Products/Debug/GPUCacheTest.app/Contents/MacOS/GPUCacheTest
```
