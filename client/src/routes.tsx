// client/src/routes.tsx
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import SignIn from './features/auth/SignIn';
import SignUp from './features/auth/SignUp';
import CreateOrg from './features/onboarding/CreateOrg';
import JoinOrg from './features/onboarding/JoinOrg';

export default function AppRoutes() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/signin" element={<SignIn onSignedIn={()=>location.assign('/')}/>} />
        <Route path="/signup" element={<SignUp onSignedUp={()=>location.assign('/onboarding')}/>} />
        <Route path="/onboarding/create-org" element={<CreateOrg/>} />
        <Route path="/onboarding/join-org" element={<JoinOrg/>} />
        <Route path="/onboarding" element={<div>
          <h2>Onboarding</h2>
          <ul>
            <li><a href="/onboarding/create-org">Create an org</a></li>
            <li><a href="/onboarding/join-org">Join with invite</a></li>
          </ul>
        </div>} />
        <Route path="/" element={<Navigate to="/onboarding" replace />} />
        <Route path="*" element={<div>Not found</div>} />
      </Routes>
    </BrowserRouter>
  );
}
