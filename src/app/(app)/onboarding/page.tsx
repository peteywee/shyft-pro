// src/app/(app)/onboarding/page.tsx
'use client';

import * as React from 'react';
import { useRouter } from 'next/navigation';
import { auth, db } from '@/lib/firebase';
import { doc, getDoc, updateDoc } from 'firebase/firestore';

type OnboardingData = {
  fullName: string;
  address: string;
  filingStatus: 'Single'|'Married'|'HeadOfHousehold';
  dependentsAmount: number;
  otherIncome: number;
  otherDeductions: number;
  extraWithholding: number;
  isMultipleJobsChecked: boolean;
  documentType: 'Passport'|'DriverLicense'|'StateID';
  documentNumber: string;
};

export default function OnboardingPage() {
  const router = useRouter();
  const [data, setData] = React.useState<OnboardingData>({
    fullName: '',
    address: '',
    filingStatus: 'Single',
    dependentsAmount: 0,
    otherIncome: 0,
    otherDeductions: 0,
    extraWithholding: 0,
    isMultipleJobsChecked: false,
    documentType: 'Passport',
    documentNumber: '',
  });
  const [error, setError] = React.useState<string|null>(null);
  const [saving, setSaving] = React.useState(false);

  React.useEffect(() => {
    // If already complete, skip
    (async () => {
      const u = auth.currentUser;
      if (!u) return;
      const snap = await getDoc(doc(db, 'users', u.uid));
      if (snap.exists() && snap.data().onboardingComplete) {
        router.replace('/dashboard');
      }
    })();
  }, [router]);

  const onSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    const u = auth.currentUser;
    if (!u) { setError('Not authenticated.'); return; }
    try {
      setSaving(true);
      await updateDoc(doc(db, 'users', u.uid), {
        ...data,
        onboardingComplete: true,
        onboardingCompletedAt: Date.now(),
      });
      router.push('/dashboard');
    } catch (err: any) {
      setError(err?.message || 'Failed to save onboarding.');
    } finally {
      setSaving(false);
    }
  };

  return (
    <main className="max-w-2xl mx-auto p-6">
      <h1 className="text-2xl font-semibold mb-4">Complete your onboarding</h1>
      {error && <p className="text-red-600 text-sm mb-3">{error}</p>}
      <form onSubmit={onSubmit} className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div>
          <label className="block text-sm">Full Name</label>
          <input className="w-full border p-2 rounded" value={data.fullName} onChange={e=>setData({...data, fullName: e.target.value})}/>
        </div>
        <div>
          <label className="block text-sm">Address</label>
          <input className="w-full border p-2 rounded" value={data.address} onChange={e=>setData({...data, address: e.target.value})}/>
        </div>
        <div>
          <label className="block text-sm">Filing Status</label>
          <select className="w-full border p-2 rounded" value={data.filingStatus} onChange={e=>setData({...data, filingStatus: e.target.value as any})}>
            <option>Single</option>
            <option>Married</option>
            <option>HeadOfHousehold</option>
          </select>
        </div>
        <div>
          <label className="block text-sm">Dependents Amount</label>
          <input type="number" className="w-full border p-2 rounded" value={data.dependentsAmount} onChange={e=>setData({...data, dependentsAmount: Number(e.target.value)})}/>
        </div>
        <div>
          <label className="block text-sm">Other Income</label>
          <input type="number" className="w-full border p-2 rounded" value={data.otherIncome} onChange={e=>setData({...data, otherIncome: Number(e.target.value)})}/>
        </div>
        <div>
          <label className="block text-sm">Other Deductions</label>
          <input type="number" className="w-full border p-2 rounded" value={data.otherDeductions} onChange={e=>setData({...data, otherDeductions: Number(e.target.value)})}/>
        </div>
        <div>
          <label className="block text-sm">Extra Withholding</label>
          <input type="number" className="w-full border p-2 rounded" value={data.extraWithholding} onChange={e=>setData({...data, extraWithholding: Number(e.target.value)})}/>
        </div>
        <div className="flex items-center gap-2">
          <input id="multi" type="checkbox" checked={data.isMultipleJobsChecked} onChange={e=>setData({...data, isMultipleJobsChecked: e.target.checked})}/>
          <label htmlFor="multi" className="text-sm">Multiple Jobs/Spouse Works</label>
        </div>
        <div>
          <label className="block text-sm">Document Type</label>
          <select className="w-full border p-2 rounded" value={data.documentType} onChange={e=>setData({...data, documentType: e.target.value as any})}>
            <option>Passport</option>
            <option>DriverLicense</option>
            <option>StateID</option>
          </select>
        </div>
        <div>
          <label className="block text-sm">Document Number</label>
          <input className="w-full border p-2 rounded" value={data.documentNumber} onChange={e=>setData({...data, documentNumber: e.target.value})}/>
        </div>

        <div className="col-span-full">
          <button disabled={saving} className="w-full bg-black text-white p-2 rounded">
            {saving ? 'Saving...' : 'Finish Onboarding'}
          </button>
        </div>
      </form>
    </main>
  );
}
