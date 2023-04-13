# SwiftPerceptualHash

Swift package to create a *Perceptual Image Hash* from a source image. To use, do as follows:

```
// Create manager only once, reuse throughout the app
let hashManager = PerceptualHashManager()

// There are many ways to get a Data type representing an image. For example:
let imageData = UIImage(named: "SampleImage".png)!.pngData()

// Once you have a reference to the Data of an image, creating the hash is easy and fast:
let hash = hashManager.perceptualHash(imageData: imageData)

// You can get different String representations from the hash. For example:
print(hash.hexString) // 2879bv9r58qsv
```
