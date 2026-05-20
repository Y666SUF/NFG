import React from "react";
import Hero from "@/components/Hero";
import TikTokMarquee from "@/components/TikTokMarquee";
import FeaturedGame from "@/components/FeaturedGame";
import GamesGrid from "@/components/GamesGrid";
import InstallSection from "@/components/InstallSection";
import Leaderboard from "@/components/Leaderboard";
import LiveSection from "@/components/LiveSection";

export default function HomePage() {
  return (
    <>
      <Hero />
      <TikTokMarquee />
      <FeaturedGame />
      <GamesGrid />
      <InstallSection />
      <Leaderboard />
      <LiveSection />
    </>
  );
}
