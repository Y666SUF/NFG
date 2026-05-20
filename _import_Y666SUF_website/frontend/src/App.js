import React from "react";
import "@/App.css";
import { BrowserRouter, Navigate, Route, Routes } from "react-router-dom";
import Navbar from "@/components/Navbar";
import Footer from "@/components/Footer";
import HomePage from "@/pages/HomePage";
import GamePage from "@/pages/GamePage";
import SideloadPage from "@/pages/SideloadPage";
import PrivacyPage from "@/pages/PrivacyPage";
import LegalPage from "@/pages/LegalPage";

function App() {
  return (
    <BrowserRouter>
      <div className="App relative" data-testid="app-root">
        <Navbar />
        <main>
          <Routes>
            <Route path="/" element={<HomePage />} />
            <Route path="/games/nfg-crash" element={<GamePage forcedSlug="nfg-crash" />} />
            <Route path="/games/nfg-wordwich" element={<GamePage forcedSlug="nfg-wordwich" />} />
            <Route path="/games/nfg-hangman" element={<GamePage forcedSlug="nfg-hangman" />} />
            <Route path="/games/nfg-wordwheel" element={<GamePage forcedSlug="nfg-wordwheel" />} />
            <Route path="/sideload" element={<SideloadPage />} />
            <Route path="/privacy" element={<PrivacyPage />} />
            <Route path="/legal" element={<LegalPage />} />
            <Route path="*" element={<Navigate to="/" replace />} />
          </Routes>
        </main>
        <Footer />
      </div>
    </BrowserRouter>
  );
}

export default App;
