import { createClient } from "@/utils/supabase/server";
import { cookies } from "next/headers";

export default async function Page() {
  const cookieStore = await cookies();
  const supabase = createClient(cookieStore);

  // Fetch todos from Supabase
  const { data: todos, error } = await supabase
    .from("todos")
    .select("*")
    .order("created_at", { ascending: false })
    .limit(50);

  return (
    <div className="min-h-screen bg-radial from-slate-900 via-slate-950 to-black text-slate-100 flex flex-col items-center justify-center p-6 sm:p-12 font-sans selection:bg-indigo-500 selection:text-white">
      {/* Background Glows */}
      <div className="absolute top-1/4 left-1/4 -translate-x-1/2 -translate-y-1/2 w-96 h-96 bg-indigo-500/10 rounded-full blur-3xl pointer-events-none" />
      <div className="absolute bottom-1/4 right-1/4 translate-x-1/2 translate-y-1/2 w-96 h-96 bg-emerald-500/10 rounded-full blur-3xl pointer-events-none" />

      <div className="w-full max-w-2xl bg-slate-900/60 backdrop-blur-xl border border-slate-800/80 rounded-3xl p-8 shadow-2xl relative overflow-hidden">
        {/* Header Decorator */}
        <div className="absolute top-0 left-0 right-0 h-1 bg-gradient-to-r from-indigo-500 via-purple-500 to-emerald-500" />
        
        <div className="flex flex-col items-center sm:items-start gap-4 mb-8">
          <div className="flex items-center gap-3">
            <span className="flex h-3 w-3 relative">
              <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75"></span>
              <span className="relative inline-flex rounded-full h-3 w-3 bg-emerald-500"></span>
            </span>
            <span className="text-xs font-semibold uppercase tracking-wider text-indigo-400">
              Supabase SSR Connection
            </span>
          </div>
          <h1 className="text-3xl sm:text-4xl font-extrabold tracking-tight bg-gradient-to-r from-white via-slate-200 to-slate-400 bg-clip-text text-transparent">
            LitOps Tasks & Todos
          </h1>
          <p className="text-sm text-slate-400">
            Realtime database entries from your Supabase instance.
          </p>
        </div>

        {error ? (
          <div className="bg-amber-500/10 border border-amber-500/20 rounded-2xl p-6 text-amber-200/90 text-sm leading-relaxed flex flex-col gap-4">
            <div className="flex items-center gap-2 font-bold text-amber-400">
              <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
              </svg>
              Database Table Notice
            </div>
            <p>
              Successfully connected to Supabase, but could not query the <code className="bg-amber-500/20 px-1.5 py-0.5 rounded text-amber-300 font-mono text-xs">todos</code> table. 
              This is typical if the table does not exist yet. You can create it in your Supabase SQL Editor:
            </p>
            <pre className="bg-slate-950/80 p-4 rounded-xl font-mono text-xs text-indigo-300 overflow-x-auto border border-slate-800">
{`CREATE TABLE todos (
  id BIGSERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  completed BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Insert dummy data
INSERT INTO todos (name) VALUES 
('Setup Next.js web application'),
('Connect Supabase SSR helpers'),
('Secure user authentication & sessions');`}
            </pre>
          </div>
        ) : !todos || todos.length === 0 ? (
          <div className="text-center py-12 flex flex-col items-center justify-center gap-4 border border-dashed border-slate-800 rounded-2xl">
            <div className="p-3 bg-indigo-500/10 rounded-full text-indigo-400">
              <svg className="w-8 h-8" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-6 9l2 2 4-4" />
              </svg>
            </div>
            <div>
              <p className="font-semibold text-slate-200">No todos found</p>
              <p className="text-xs text-slate-500 mt-1">Insert a row into the database to see it update here.</p>
            </div>
          </div>
        ) : (
          <ul className="flex flex-col gap-3">
            {todos.map((todo) => (
              <li 
                key={todo.id}
                className="flex items-center justify-between p-4 rounded-xl bg-slate-800/40 border border-slate-800 hover:border-slate-700/80 transition-all duration-300 hover:bg-slate-800/60 group"
              >
                <div className="flex items-center gap-3">
                  <span className="h-5 w-5 rounded-full border border-indigo-500/30 flex items-center justify-center text-indigo-400 bg-indigo-500/5 group-hover:scale-105 transition-transform">
                    ✓
                  </span>
                  <span className="text-sm font-medium text-slate-200 group-hover:text-white transition-colors">
                    {todo.name}
                  </span>
                </div>
                <span className="text-xs text-slate-500 font-mono">
                  ID: {todo.id}
                </span>
              </li>
            ))}
          </ul>
        )}
        
        {/* Footer info */}
        <div className="mt-8 pt-6 border-t border-slate-800/80 flex flex-col sm:flex-row items-center justify-between gap-4 text-xs text-slate-500">
          <p>Next.js App Router + Supabase SSR</p>
          <a 
            href="https://supabase.com/docs/guides/auth/server-side/nextjs"
            target="_blank"
            rel="noopener noreferrer"
            className="hover:text-indigo-400 transition-colors flex items-center gap-1"
          >
            Documentation 
            <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
            </svg>
          </a>
        </div>
      </div>
    </div>
  );
}
