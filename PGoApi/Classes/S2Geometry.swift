//
//  S2Geometry.swift
//  pgomap
//
//  Created by Luke Sapan on 7/21/16.
//  Copyright © 2016 Coadstal. All rights reserved.
//

import Foundation


public enum S2Projection {
    case Linear
    case Tan
    case Quadratic
}

public enum S2Constants {
    public static let maxLevel:Int64 = 30
    public static let posBits:Int64 = 2 * S2Constants.maxLevel + 1
    public static let maxSize:Int64 = 1 << S2Constants.maxLevel
    public static let swapMask:Int64 = 0x01
    public static let invertMask:Int64 = 0x02
    public static let lookupBits:Int64 = 4
    public static let posToOrientation = [S2Constants.swapMask, 0, 0, S2Constants.invertMask | S2Constants.swapMask]
    public static let posToIj:Array<Array<Int64>> = [[0, 1, 3, 2],
                                              [0, 2, 3, 1],
                                              [3, 2, 0, 1],
                                              [3, 1, 0, 2]]
}

public struct S2FaceUv {
    public let face: Int64
    public let u: Double
    public let v: Double
}

public struct S2Uv {
    public let u: Double
    public let v: Double
}

public class S2Helper {
    public static let sharedInstance = S2Helper()
    
    public var lookupPos: [Int64?] = []
    public var lookupIJ: [Int64?] = []
    
    public init() {
        for _ in 0..<(1 << (2 * S2Constants.lookupBits + 2)) {
            lookupPos.append(nil)
            lookupIJ.append(nil)
        }
        initLookupCell(0, i: 0, j: 0, origOrientation: 0, pos: 0, orientation: 0)
        initLookupCell(0, i: 0, j: 0, origOrientation: S2Constants.swapMask, pos: 0, orientation: S2Constants.swapMask)
        initLookupCell(0, i: 0, j: 0, origOrientation: S2Constants.invertMask, pos: 0, orientation: S2Constants.invertMask)
        initLookupCell(0, i: 0, j: 0, origOrientation: S2Constants.swapMask | S2Constants.invertMask, pos: 0, orientation: S2Constants.swapMask | S2Constants.invertMask)
    }
    
    public func initLookupCell(level: Int64, i: Int64, j: Int64, origOrientation: Int64, pos: Int64, orientation: Int64) {
        if level == S2Constants.lookupBits {
            let ij = (i << S2Constants.lookupBits) + j
            lookupPos[Int((ij << 2) + origOrientation)] = (pos << 2) + orientation
            lookupIJ[Int((pos << 2) + origOrientation)] = (ij << 2) + orientation
        } else {
            let _level = level + 1
            let _i = i << 1
            let _j = j << 1
            let _pos = pos << 2
            let r = S2Constants.posToIj[Int(orientation)]
            for index in 0..<4 {
                initLookupCell(_level, i: _i + (r[index] >> 1), j: _j + (r[index] & 1), origOrientation: origOrientation, pos: _pos + index, orientation: orientation ^ S2Constants.posToOrientation[index])
            }
        }
    }
}

public class S2Point {
    public let x: Double
    public let y: Double
    public let z: Double
    
    public init(x: Double, y: Double, z: Double) {
        self.x = x
        self.y = y
        self.z = z
    }
    
    public func pointAbs() -> [Double] {
        return [abs(x), abs(y), abs(z)]
    }
    
    public func largestAbsComponent() -> Int64 {
        let temp = pointAbs()
        if temp[0] > temp[1] {
            if temp[0] > temp[2] {
                return 0
            } else {
                return 2
            }
        } else {
            if temp[1] > temp[2] {
                return 1
            } else {
                return 2
            }
        }
    }
    
    public func dotProd(o: S2Point) -> Double {
        return x * o.x + y * o.y + z * o.z
    }
    
    public static func faceUvToXyz(face: Int64, u: Double, v: Double) -> S2Point {
        let uDouble = Double(u)
        let vDouble = Double(v)
        if face == 0 {
            return S2Point(x: 1, y: uDouble, z: vDouble)
        } else if face == 1 {
            return S2Point(x: -uDouble, y: 1, z: vDouble)
        } else if face == 2 {
            return S2Point(x: -uDouble, y: -vDouble, z: 1)
        } else if face == 3 {
            return S2Point(x: -1, y: -vDouble, z: -uDouble)
        } else if face == 4 {
            return S2Point(x: vDouble, y: -1, z: -uDouble)
        } else {
            return S2Point(x: vDouble, y: uDouble, z: -1)
        }
    }
    
    public func get(axis: Int64) -> Double {
        return (axis == 0) ? x : (axis == 1) ? y : z
    }
}

public class S2LatLon {
    public let lat: Double
    public let lon: Double
    
    public init(latDegrees: Double, lonDegrees: Double) {
        lat = latDegrees * M_PI / 180
        lon = lonDegrees * M_PI / 180
    }
    
    public func toPoint() -> S2Point {
        let phi = lat
        let theta = lon
        let cosphi = cos(phi)
        return S2Point(x: cos(theta) * cosphi, y: sin(theta) * cosphi, z: sin(phi))
    }
}

public class S2CellId: Equatable {
    public var id: UInt64
    
    public init(id: UInt64) {
        self.id = id
    }
    
    public convenience init(p: S2Point) {
        let faceUv = S2CellId.xyzToFaceUv(p)
        let i = S2CellId.stToIj(S2CellId.uvToSt(.Quadratic, u: faceUv.u))
        let j = S2CellId.stToIj(S2CellId.uvToSt(.Quadratic, u: faceUv.v))
        self.init(face: faceUv.face, i: i, j: j)
    }
    
    public convenience init(face: Int64, i: Int64, j: Int64) {
        var n = face << (S2Constants.posBits - 1)
        var bits = face & S2Constants.swapMask
        
        for k in 7.stride(to: -1, by: -1) {
            let mask = (1 << S2Constants.lookupBits) - 1
            bits += (((i >> (Int64(k) * S2Constants.lookupBits)) & mask) << (S2Constants.lookupBits + 2))
            bits += (((j >> (Int64(k) * S2Constants.lookupBits)) & mask) << 2)
            bits = S2Helper.sharedInstance.lookupPos[Int(bits)]!
            n |= (bits >> 2) << (Int64(k) * 2 * S2Constants.lookupBits)
            bits &= (S2Constants.swapMask | S2Constants.invertMask)
        }
        
        self.init(id: UInt64(n) * 2 + 1)
    }
    
    public static func getBits(inout n: [Int64], i: Int64, j: Int64, k: Int64, inout bits: Int64) {
        let mask: Int64 = (1 << S2Constants.lookupBits) - 1
        bits += (((i >> (k * S2Constants.lookupBits)) & mask) << (S2Constants.lookupBits + 2))
        bits += (((j >> (k * S2Constants.lookupBits)) & mask) << 2)
        bits = S2Helper.sharedInstance.lookupPos[Int(bits)]!
        n[Int(k >> 2)] |= ((bits >> 2) << ((k & 3) * 2 * S2Constants.lookupBits))
        bits &= (S2Constants.swapMask | S2Constants.invertMask)
    }
    
    public func getBitsForIJ(inout i: Int64, inout j: Int64, k: Int64, inout bits: Int64) {
        let nbits: Int64 = (k == 7) ? (S2Constants.maxLevel - 7 * S2Constants.lookupBits) : S2Constants.lookupBits
        bits += (((id.getInt64() >> (k * 2 * S2Constants.lookupBits + 1)) & ((1 << (2 * nbits)) - 1))) << 2
        bits = S2Helper.sharedInstance.lookupIJ[Int(bits)]!
        i = (i + ((bits >> (S2Constants.lookupBits + 2)) << (k * S2Constants.lookupBits)))
        j = (j + ((((bits >> 2) & ((1 << S2Constants.lookupBits) - 1))) << (k * S2Constants.lookupBits)))
        bits &= (S2Constants.swapMask | S2Constants.invertMask)
    }
    
    public func toFaceIJOrientation(inout pi: Int64, inout pj: Int64, inout orientation: Int64?) -> Int64 {
        let face: Int64 = self.face()
        var bits: Int64 = (face & S2Constants.swapMask)
        
        for k in 7.stride(through: 0, by: -1) {
            getBitsForIJ(&pi, j: &pj, k: Int64(k), bits: &bits)
        }
        
        if (orientation != nil) {
            let id_ = id.getInt64()
            if ((id_ & -id_) & 0x1111111111111110) != 0 {
                bits ^= S2Constants.swapMask
            }
            orientation = bits
        }
        return face
    }
    
    public static func xyzToFaceUv(p: S2Point) -> S2FaceUv {
        var face = p.largestAbsComponent()
        var pFace: Double
        if face == 0 {
            pFace = p.x
        } else if face == 1 {
            pFace = p.y
        } else {
            pFace = p.z
        }
        if pFace < 0 {
            face += 3
        }
        let uv = validFaceXyzToUv(face, p: p)
        return S2FaceUv(face: face, u: uv.u, v: uv.v)
    }
    
    public static func xyzToFace(p: S2Point) -> Int64 {
        var face = p.largestAbsComponent()
        if (p.get(face) < 0) {
            face += 3
        }
        return face
    }
    
    public static func uvToSt(projection: S2Projection, u: Double) -> Double {
        if projection == .Linear {
            return 0.5 * (u + 1)
        } else if projection == .Tan {
            return (2 * (1.0 / M_PI)) * (atan(u) * M_PI / 4.0)
        } else {
            if u >= 0 {
                return 0.5 * sqrt(1 + 3 * u)
            } else {
                return 1 - 0.5 * sqrt(1 - 3 * u)
            }
        }
    }
    
    public static func stToIj(s: Double) -> Int64 {
        return max(0, min(S2Constants.maxSize - 1, Int64(floor(Double(S2Constants.maxSize) * s))))
    }
    
    public static func validFaceXyzToUv(face: Int64, p: S2Point) -> S2Uv {
        assert(p.dotProd(S2Point.faceUvToXyz(face, u: 0, v: 0)) > 0)
        if face == 0 {
            return S2Uv(u: p.y / p.x, v: p.z / p.x)
        } else if face == 1 {
            return S2Uv(u: -p.x / p.y, v: p.z / p.y)
        } else if face == 2 {
            return S2Uv(u: -p.x / p.z, v: -p.y / p.z)
        } else if face == 3 {
            return S2Uv(u: p.z / p.x, v: p.y / p.x)
        } else if face == 4 {
            return S2Uv(u: p.z / p.y, v: -p.x / p.y)
        } else {
            return S2Uv(u: -p.y / p.z, v: -p.x / p.z)
        }
    }
    
    public static func fromFaceIJWrap(face: Int64, i: Int64, int j: Int64) -> S2CellId {
        let i = max(-1, min(S2Constants.maxSize, i))
        let j = max(-1, min(S2Constants.maxSize, j))
        
        let kScale: Double = 1.0 / Double(S2Constants.maxSize)
        let s: Double = kScale * Double((i << 1) + 1 - S2Constants.maxSize)
        let t: Double = kScale * Double((j << 1) + 1 - S2Constants.maxSize)
        
        let p: S2Point = S2Point.faceUvToXyz(face, u: s, v: t)
        let face = S2CellId.xyzToFace(p)
        let st = S2CellId.validFaceXyzToUv(face, p: p)
        return fromFaceIJ(face, i: S2CellId.stToIj(st.u), j: stToIj(st.v))
    }
    
    public static func fromFaceIJ(face: Int64, i: Int64, j: Int64) -> S2CellId {
        var n: [Int64] = [0, face << (S2Constants.posBits - 33)]
        var bits: Int64 = (face & S2Constants.swapMask)
        
        for k in 7.stride(to: -1, by: -1) {
            getBits(&n, i: i, j: j, k: Int64(k), bits: &bits)
        }
        
        return S2CellId(id: ((((n[1] << 32) + n[0]) << 1) + 1).getUInt64())
    }
    
    public static func fromFaceIJSame(face: Int64, i: Int64, j: Int64, sameFace: Bool) -> S2CellId {
        if (sameFace) {
            return fromFaceIJ(face, i: i, j: j)
        } else {
            return fromFaceIJWrap(face, i: i, int: j)
        }
    }
    
    public func lsb() -> UInt64 {
        return UInt64(bitPattern: Int64(bitPattern: id) & (0 &- Int64(bitPattern: id)))
    }
    
    public func prev() -> S2CellId{
        return S2CellId(id: id - (lsb() << 1))
    }
    
    public func next() -> S2CellId {
        return S2CellId(id: id + (lsb() << 1))
    }
    
    public func lsbForLevel(level: UInt64) -> UInt64 {
        return 1 << (2 * (30 - level))
    }

    public func parent(level: UInt64) -> S2CellId {
        let newLsb = self.lsbForLevel(level)
        let newId = (self.id.getInt64() & -newLsb.getInt64()) | newLsb.getInt64()
        self.id = newId.getUInt64()
        return self
    }
    
    public func face() -> Int64 {
        return self.id.getInt64() >> S2Constants.posBits
    }
    
    public func level() -> Int64 {
        var x = self.id
        var level: Int64 = -1
        
        if (x != 0) {
            level += 16
        } else {
            x = (self.id >> 32)
        }
        
        if (x & 0x00005555) != 0 {
            level += 8
        }
        if (x & 0x00550055) != 0 {
            level += 4
        }
        if (x & 0x05050505) != 0 {
            level += 2
        }
        if (x & 0x11111111) != 0 {
            level += 1
        }

        return level
    }

    public func getAllNeighbors(level: Int64) -> [S2CellId] {
        var output = [S2CellId]()
        var i: Int64 = 0
        var j: Int64 = 0
        var orientation: Int64? = nil
        let face = self.toFaceIJOrientation(&i, pj: &j, orientation: &orientation)
        
        let size:Int64 = 1 << (S2Constants.maxLevel - self.level())
        i = (i & -size)
        j = (j & -size)
        
        let nbrSize:Int64 = 1 << (S2Constants.maxLevel - level)
        let nbrSizeInverted = Int((-nbrSize))
        
        nbrSizeInverted.strideByInt(to: Int(size), by: Int(nbrSize)) {k in
            var sameFace: Bool
            if (k < 0) {
                sameFace = (j + k >= 0)
            } else if (k >= size) {
                sameFace = (j + k < S2Constants.maxSize)
            } else {
                sameFace = true
                output.append(S2CellId.fromFaceIJSame(face, i: i + k, j: j - nbrSize, sameFace: j - size >= 0).parent(UInt64(level)))
                output.append(S2CellId.fromFaceIJSame(face, i: i + k, j: j + size, sameFace: j + size < S2Constants.maxSize).parent(UInt64(level)))
            }
            output.append(S2CellId.fromFaceIJSame(face, i: i - nbrSize, j: j + k, sameFace: sameFace && i - size >= 0).parent(UInt64(level)))
            output.append(S2CellId.fromFaceIJSame(face, i: i + size, j: j + k, sameFace: sameFace && i + size < S2Constants.maxSize).parent(UInt64(level)))
        }
        return output
    }
    
    public func getEdgeNeighbors() -> [S2CellId] {
        var neighbors: [S2CellId] = []
        var i: Int64 = 0
        var j: Int64 = 0
        var orientation: Int64? = nil

        let level = self.level()
        
        let size = 1 << (S2Constants.maxLevel - level)
        let face = toFaceIJOrientation(&i, pj: &j, orientation: &orientation)
        
        neighbors.append(S2CellId.fromFaceIJSame(face, i: i, j: j - size, sameFace: j - size >= 0).parent(UInt64(level)))
        neighbors.append(S2CellId.fromFaceIJSame(face, i: i + size, j: j, sameFace: i + size < S2Constants.maxSize).parent(UInt64(level)))
        neighbors.append(S2CellId.fromFaceIJSame(face, i: i, j: j + size, sameFace: j + size < S2Constants.maxSize).parent(UInt64(level)))
        neighbors.append(S2CellId.fromFaceIJSame(face, i: i - size, j: j, sameFace: i - size >= 0).parent(UInt64(level)))
        
        return neighbors
    }
}


public func ==(lhs: S2CellId, rhs: S2CellId) -> Bool {
    return lhs.id == rhs.id
}