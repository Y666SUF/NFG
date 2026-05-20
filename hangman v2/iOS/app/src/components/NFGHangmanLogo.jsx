/** Wordmark aligned with NFG Crash (purple/pink NFG + cyan hangman accent). */
export default function NFGHangmanLogo({ height = 44, className = "" }) {
  return (
    <img
      src="/nfg-hangman-logo.svg"
      alt="NFG Hangman"
      className={className}
      style={{ height, width: "auto", display: "block" }}
      draggable={false}
    />
  );
}
