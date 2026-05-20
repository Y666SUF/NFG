import React, { useRef, useMemo, Suspense } from "react";
import { Canvas, useFrame } from "@react-three/fiber";
import { Stars, Sparkles, Float, Icosahedron, Torus, MeshDistortMaterial } from "@react-three/drei";

function CosmicOrb({ position = [0, 0, 0], color = "#00F0FF", scale = 1.2, speed = 0.2 }) {
  const ref = useRef();
  useFrame((_, delta) => {
    if (ref.current) {
      ref.current.rotation.y += delta * speed;
      ref.current.rotation.x += delta * speed * 0.4;
    }
  });
  return (
    <Float speed={1.2} rotationIntensity={0.6} floatIntensity={1.4}>
      <Icosahedron ref={ref} args={[1, 3]} position={position} scale={scale}>
        <MeshDistortMaterial
          color={color}
          emissive={color}
          emissiveIntensity={0.8}
          distort={0.45}
          speed={1.8}
          roughness={0.2}
          metalness={0.6}
        />
      </Icosahedron>
    </Float>
  );
}

function WireOrb({ position, color = "#FF003C", scale = 0.9 }) {
  const ref = useRef();
  useFrame((_, delta) => {
    if (ref.current) {
      ref.current.rotation.y -= delta * 0.25;
      ref.current.rotation.z += delta * 0.1;
    }
  });
  return (
    <Float speed={0.9} rotationIntensity={0.4} floatIntensity={1.0}>
      <Icosahedron ref={ref} args={[1, 1]} position={position} scale={scale}>
        <meshBasicMaterial color={color} wireframe transparent opacity={0.55} />
      </Icosahedron>
    </Float>
  );
}

function RingSystem({ position = [0, 0, 0] }) {
  const ref = useRef();
  useFrame((_, delta) => {
    if (ref.current) {
      ref.current.rotation.x += delta * 0.15;
      ref.current.rotation.y += delta * 0.08;
    }
  });
  return (
    <group ref={ref} position={position} rotation={[Math.PI / 3, 0, 0]}>
      <Torus args={[2.4, 0.012, 16, 200]}>
        <meshBasicMaterial color="#00F0FF" transparent opacity={0.55} />
      </Torus>
      <Torus args={[2.8, 0.008, 16, 200]}>
        <meshBasicMaterial color="#FF003C" transparent opacity={0.4} />
      </Torus>
      <Torus args={[3.2, 0.006, 16, 200]}>
        <meshBasicMaterial color="#8A2BE2" transparent opacity={0.3} />
      </Torus>
    </group>
  );
}

function Asteroids({ count = 28 }) {
  const group = useRef();
  const items = useMemo(
    () =>
      new Array(count).fill(0).map(() => ({
        pos: [
          (Math.random() - 0.5) * 18,
          (Math.random() - 0.5) * 10,
          (Math.random() - 0.5) * 12 - 4,
        ],
        scale: 0.05 + Math.random() * 0.18,
        rot: [Math.random() * Math.PI, Math.random() * Math.PI, Math.random() * Math.PI],
      })),
    [count]
  );
  useFrame((_, delta) => {
    if (group.current) group.current.rotation.y += delta * 0.02;
  });
  return (
    <group ref={group}>
      {items.map((it, i) => (
        <mesh key={i} position={it.pos} rotation={it.rot} scale={it.scale}>
          <dodecahedronGeometry args={[1, 0]} />
          <meshStandardMaterial
            color="#5a5a7a"
            emissive="#00F0FF"
            emissiveIntensity={0.18}
            roughness={0.9}
          />
        </mesh>
      ))}
    </group>
  );
}

export default function Scene3D({ intensity = "hero" }) {
  const isHero = intensity === "hero";
  return (
    <Canvas
      dpr={[1, 1.6]}
      camera={{ position: [0, 0, 6], fov: 55 }}
      gl={{ antialias: true, alpha: true, powerPreference: "high-performance" }}
      style={{ position: "absolute", inset: 0 }}
    >
      <color attach="background" args={["#05050A"]} />
      <fog attach="fog" args={["#05050A", 8, 22]} />

      <ambientLight intensity={0.25} />
      <pointLight position={[5, 5, 5]} intensity={1.4} color="#00F0FF" />
      <pointLight position={[-6, -3, -2]} intensity={1.1} color="#FF003C" />
      <pointLight position={[0, 4, -4]} intensity={0.6} color="#8A2BE2" />

      <Suspense fallback={null}>
        <Stars radius={80} depth={50} count={isHero ? 4500 : 2200} factor={4} fade speed={0.6} />
        <Sparkles count={isHero ? 120 : 60} scale={[14, 8, 8]} size={2.2} speed={0.4} color="#00F0FF" />
        <Sparkles count={isHero ? 60 : 30} scale={[14, 8, 8]} size={1.6} speed={0.3} color="#FF003C" />

        {isHero && <CosmicOrb position={[2.4, 0.2, -0.5]} color="#00F0FF" scale={1.4} />}
        {isHero && <WireOrb position={[-3.0, -0.6, 0.5]} color="#FF003C" scale={1.1} />}
        {isHero && <RingSystem position={[2.4, 0.2, -0.5]} />}

        <Asteroids count={isHero ? 32 : 16} />
      </Suspense>
    </Canvas>
  );
}
