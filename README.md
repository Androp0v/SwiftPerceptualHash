# SwiftPerceptualHash

Swift package to create a *Perceptual Image Hash* from a source image. Perceptual Image Hashes output similar hashes for similar images, which allows for easy duplicate image detection that is robust to different compression algorithms or image sizes.

## How to use

```swift
// Create manager only once, reuse throughout the app
let hashManager = PerceptualHashManager()

// There are many ways to get a Data type representing an image. For example:
let imageData = UIImage(named: "SampleImage".png)!.pngData()

// Once you have a reference to the Data of an image, creating the hash is easy and fast:
let hash = hashManager.perceptualHash(imageData: imageData)

// You can get different String representations from the hash. For example:
print(hash.hexString) // 2879bv9r58qsv
```

## Algorithm overview

### Original image
![OriginalImage](Images/Original.png)

### Low-pass filter
![LowPassImage](Images/LowPass.png)

### Downsampling
![Downsampled](Images/Downsampled.png)

### Discrete Cosine Transform (DCT)
![DCT](Images/DCT.png)

### Hash
![Hash](Images/Hash.png)
