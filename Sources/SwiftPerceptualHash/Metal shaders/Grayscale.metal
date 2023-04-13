//
//  Grayscale.metal
//  SwiftPerceptualHashApp
//
//  Created by Raúl Montón Pinillos on 12/4/23.
//

#include <metal_stdlib>
using namespace metal;

// Rec 709 LUMA values for grayscale image conversion
constant half3 kRec709Luma = half3(0.2126, 0.7152, 0.0722);

kernel void grayscale_kernel(texture2d<half, access::read> source_texture [[texture(0)]],
                             texture2d<half, access::write> output_texture [[texture(1)]],
                             uint2 gid [[thread_position_in_grid]]) {
    half4 inColor = source_texture.read(gid);
    half gray = dot(inColor.rgb, kRec709Luma);
    output_texture.write(gray, gid);
}
