export default function LoadingSpinner() {
  return (
    <div className="flex items-center justify-center min-h-screen bg-white dark:bg-black">
      <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-black dark:border-white"></div>
    </div>
  );
}

