//
//  CustomStyleLayerExample.swift
//  MetalRenderMap
//
//  Created by Võ Toàn on 04/03/2024.
//

#if !MLN_RENDER_BACKEND_METAL

import Foundation
import GLKit
import MapLibre

class CustomStyleLayer: MLNCustomStyleLayer {

    var program: GLuint = 0
    var vertexShader: GLuint = 0
    var fragmentShader: GLuint = 0
    var buffer: GLuint = 0
    var aPos: GLuint = 0

    override func didMove(to mapView: MLNMapView) {
        let vertexShaderSource = NSString("#version 300 es\nlayout (location = 0) in vec2 a_pos; void main() { gl_Position = vec4(a_pos, 1, 1); }")

        let fragmentShaderSource = NSString("#version 300 es\nout highp vec4 fragColor; void main() { fragColor = vec4(0, 0.5, 0, 0.5); }")

        program = glCreateProgram()
        vertexShader = glCreateShader(GLenum(GL_VERTEX_SHADER))
        fragmentShader = glCreateShader(GLenum(GL_FRAGMENT_SHADER))

        let vertexShaderSourceStringUTF8 = vertexShaderSource.utf8String
        let fragmentShaderSourceStringUTF8 = fragmentShaderSource.utf8String

        glShaderSource(vertexShader, 1, [vertexShaderSourceStringUTF8], nil)
        glCompileShader(vertexShader)
        glAttachShader(program, vertexShader)
        glShaderSource(fragmentShader, 1, [fragmentShaderSourceStringUTF8], nil)
        glCompileShader(fragmentShader)
        glAttachShader(program, fragmentShader)
        glLinkProgram(program)
        aPos = GLuint(glGetAttribLocation(program, "a_pos"))

        let triangle: [GLfloat] = [ 0, 0.5, 0.5, -0.5, -0.5, -0.5 ]
        glGenBuffers(1, &buffer)
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), buffer)
        glBufferData(GLenum(GL_ARRAY_BUFFER), MemoryLayout<GLfloat>.size * triangle.count, triangle, GLenum(GL_STATIC_DRAW))
    }

    override func draw(in mapView: MLNMapView, with context: MLNStyleLayerDrawingContext) {
        glUseProgram(program)
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), buffer)
        glEnableVertexAttribArray(aPos)
        glVertexAttribPointer(aPos, 2, GLenum(GL_FLOAT), GLboolean(GL_FALSE), 0, nil)
        glDisable(GLenum(GL_STENCIL_TEST))
        glDisable(GLenum(GL_DEPTH_TEST))
        glDrawArrays(GLenum(GL_TRIANGLE_STRIP), 0, 3)
    }

    override func willMove(from mapView: MLNMapView) {
        guard program > 0 else { return }

        glDeleteBuffers(1, &buffer)
        glDetachShader(program, vertexShader)
        glDetachShader(program, fragmentShader)
        glDeleteShader(vertexShader)
        glDeleteShader(fragmentShader)
        glDeleteProgram(program)
    }
}

#else // MLN_RENDER_BACKEND_METAL:

class MetalCustomStyleLayerExample: MLNCustomStyleLayer {
    var pipelineState: MTLRenderPipelineState?  // Optional type for potential nil value
    var depthStencilStateWithoutStencil: MTLDepthStencilState? // Optional type for potential nil value

    override func didMove(to mapView: MLNMapView) {
        let resource = mapView.backendResource

        let shaderSource = """
            #include <metal_stdlib>
            using namespace metal;

            struct Vertex {
                float2 position;
                float4 color;
            };

            struct RasterizerData {
                float4 position [[position]];
                float4 color;
            };

            vertex RasterizerData vertexShader(uint vertexID [[vertex_id]],
                                               constant Vertex* vertices [[buffer(0)]],
                                               constant vector_uint2* viewportSizePointer [[buffer(1)]]) {
                RasterizerData out;
                float2 pixelSpacePosition = vertices[vertexID].position.xy;
                vector_float2 viewportSize = vector_float2(*viewportSizePointer);
                out.position = vector_float4(0.0, 0.0, 0.0, 1.0);
                out.position.xy = pixelSpacePosition / (viewportSize / 2.0);
                out.color = vertices[vertexID].color;
                return out;
            }

            fragment float4 fragmentShader(RasterizerData in [[stage_in]]) {
                return in.color;
            }
        """

        var error: NSError?
        let device = resource.device

        guard let library = try? device.makeLibrary(source: shaderSource, options: nil) else {
            fatalError("Error compiling shaders: \(error!)")
        }

        let vertexFunction = library.makeFunction(name: "vertexShader")!
        let fragmentFunction = library.makeFunction(name: "fragmentShader")!

        // Configure a pipeline descriptor
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.label = "Simple Pipeline"
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = resource.mtkView.colorPixelFormat
        pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float_stencil8
        pipelineDescriptor.stencilAttachmentPixelFormat = .depth32Float_stencil8

        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            fatalError("Failed to create pipeline state: \(error)")
        }

        // Configure depth stencil descriptor
        let depthStencilDescriptor = MTLDepthStencilDescriptor()
        depthStencilDescriptor.depthCompareFunction = .always // Or another value as needed
        depthStencilDescriptor.depthWriteEnabled = false

        depthStencilStateWithoutStencil = device.newDepthStencilState(withDescriptor: depthStencilDescriptor)
    }

    func drawInMapView(_ mapView: MLNMapView, with context: MLNStyleLayerDrawingContext) {
        guard let renderEncoder = self.renderEncoder else { return } // Early exit if encoder is nil

        let resource = mapView.backendResource
        let viewportSize = vector_uint2(x: resource.mtkView.drawableSize.width, y: resource.mtkView.drawableSize.height)

        struct Vertex {
            let position: vector_float2
            let color: vector_float4
        }

        let triangleVertices: [Vertex] = [
            Vertex(position: vector_float2(x: 250, y: -250), color: vector_float4(x: 1, y: 0, z: 0, w: 1)),
            Vertex(position: vector_float2(x: -250, y: -250), color: vector_float4(x: 0, y: 1, z: 0, w: 1)),
            Vertex(position: vector_float2(x: 0, y: 250), color: vector_float4(x: 0, y: 0, z: 1, w: 1)),
        ]

        renderEncoder.setRenderPipelineState(_pipelineState)
        renderEncoder.setDepthStencilState(_depthStencilStateWithoutStencil)

        renderEncoder.setVertexBytes(triangleVertices, length: MemoryLayout<Vertex>.stride * triangleVertices.count, at: 0)
        renderEncoder.setVertexBytes(&viewportSize, length: MemoryLayout<vector_uint2>.stride, at: 1)

        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
    }

    override func willMove(from mapView: MLNMapView) {
        // Clean up logic here
    }
}

#endif
