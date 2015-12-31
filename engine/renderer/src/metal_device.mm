#include "metal_device.h"

#import <Metal/Metal.h>

#include <unordered_map>

namespace JMD {
namespace GFX {
static id <MTLDevice> mtl_device;
void LoadDevice() {
    mtl_device = MTLCreateSystemDefaultDevice();
}
#pragma mark Impls
struct BufferImpl {
    BufferImpl(){}
    id<MTLBuffer> buffer;
};
bool Buffer::Initialise(const char* const data, const unsigned int length) {
    this->Create();
    impl->buffer = [mtl_device newBufferWithBytes:data length:length options:MTLResourceOptionCPUCacheModeDefault];
    return true;
}
void Buffer::Create() {
    if(impl == nullptr) impl = new BufferImpl();
}
void Buffer::Release() {delete impl;}
    
struct PixelFormatImpl {
    PixelFormatImpl():data(MTLPixelFormatInvalid){}
    MTLPixelFormat data;
};
void PixelFormat::Create() {
    if(impl == nullptr) impl = new PixelFormatImpl();
}
void PixelFormat::Release() {delete impl;}
    
struct LibraryImpl {
    id<MTLLibrary> data;
};
void Library::Create() {
    if(impl == nullptr) impl = new LibraryImpl();
}
void Library::Release() {delete impl;}
    
struct EffectImpl {
    id<MTLFunction> vertex_fn;
    id<MTLFunction> fragment_fn;
};
void Effect::Create() {
    if(impl == nullptr) impl = new EffectImpl();
}
void Effect::Release() {delete impl;}
    
struct PipelineDescImpl {
    MTLRenderPipelineDescriptor* data;
};
void PipelineDesc::Create() {
    if(impl == nullptr) {
        impl = new PipelineDescImpl();
        impl->data = [[MTLRenderPipelineDescriptor alloc] init];
    }
}
void PipelineDesc::Release() {delete impl;}
    
struct PipelineStateImpl {
    id<MTLRenderPipelineState> data;
};
void PipelineState::Create() {
    if(impl == nullptr) impl = new PipelineStateImpl();
}
void PipelineState::Release() {delete impl;}
    
#pragma mark Member functions
bool PixelFormat::Load(const std::string &pixel_format){
    this->Create();
    MTLPixelFormat& mtl_pixel_format(impl->data);
    // Find the requested format
    std::unordered_map<std::string,MTLPixelFormat> pixel_format_map{
        {"BGRA8U",MTLPixelFormatBGRA8Unorm},
        {"D32F",MTLPixelFormatDepth32Float}
    };
    const auto selected(pixel_format_map.find(pixel_format));
    if(selected != pixel_format_map.end()){
        mtl_pixel_format = selected->second;
    }else{
        return false;
    }
    return true;
}
void Library::Load(const std::string &name) {
    this->Create();
    if(name == ""){
        impl->data = [mtl_device newDefaultLibrary];
    }else{
        assert(0);
    }
    if(!impl->data) {
        NSLog(@">> ERROR: Couldnt create a shader library %s",name.c_str());
        assert(0);
    }
    impl->data.label = [[NSString alloc]initWithCString:name.c_str() encoding:NSASCIIStringEncoding];
}
void Effect::Load(Library& library, const std::string &vert_name, const std::string &frag_name){
    this->Create();
    id<MTLLibrary> mtl_library(library.impl->data);
    NSString* vert_nsstring = [[NSString alloc]initWithCString:vert_name.c_str() encoding:NSASCIIStringEncoding];
    impl->vertex_fn = [mtl_library newFunctionWithName:vert_nsstring];
    if(!impl->vertex_fn)
        NSLog(@">> ERROR: Couldn't load %@ vertex program from supplied library (%@)", vert_nsstring, mtl_library.label);
    assert(impl->vertex_fn.functionType == MTLFunctionType::MTLFunctionTypeVertex);
    NSString* frag_nsstring = [[NSString alloc]initWithCString:frag_name.c_str() encoding:NSASCIIStringEncoding];
    impl->fragment_fn = [mtl_library newFunctionWithName:frag_nsstring];
    if(!impl->fragment_fn)
        NSLog(@">> ERROR: Couldn't load %@ fragment program from supplied library (%@)", frag_nsstring, mtl_library.label);
    assert(impl->fragment_fn.functionType == MTLFunctionType::MTLFunctionTypeFragment);
}
void PipelineDesc::Load(Effect& effect,
                        const unsigned int sample_count,
                        const std::vector<PixelFormat>& colour_formats,
                        const PixelFormat& depth_format,
                        const PixelFormat& stencil_format) {
    this->Create();
    MTLRenderPipelineDescriptor* mtl_pipeline_descriptor(impl->data);
    mtl_pipeline_descriptor.sampleCount = sample_count;
    assert(effect.impl != nullptr);
    mtl_pipeline_descriptor.fragmentFunction = effect.impl->fragment_fn;
    mtl_pipeline_descriptor.vertexFunction = effect.impl->vertex_fn;
    for (unsigned int index=0; index < colour_formats.size(); ++index) {
        const PixelFormat& pixel_format(colour_formats.at(index));
        if(pixel_format.impl != nullptr && pixel_format.impl->data != MTLPixelFormatInvalid)
            mtl_pipeline_descriptor.colorAttachments[index].pixelFormat = pixel_format.impl->data;
    }
    if(depth_format.impl != nullptr && depth_format.impl->data != MTLPixelFormatInvalid)
        mtl_pipeline_descriptor.depthAttachmentPixelFormat = depth_format.impl->data;
    if(stencil_format.impl != nullptr && stencil_format.impl->data != MTLPixelFormatInvalid)
        mtl_pipeline_descriptor.stencilAttachmentPixelFormat = stencil_format.impl->data;
}
void PipelineState::Load(const JMD::GFX::PipelineDesc &pipeline_descriptor) {
    this->Create();
    MTLRenderPipelineDescriptor* mtl_pipeline_desc(pipeline_descriptor.impl->data);
    assert(mtl_pipeline_desc != nullptr);
    NSError *error = nil;
    impl->data = [mtl_device newRenderPipelineStateWithDescriptor:mtl_pipeline_desc error:&error];
    if(!impl->data) {
        NSLog(@">> ERROR: Failed Aquiring pipeline state: %@", error);
    }
}
}}