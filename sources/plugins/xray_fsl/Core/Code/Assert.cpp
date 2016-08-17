#include "stdafx.h"
#include "Assert.h"
#include "Prerequisites.h"

namespace xrFSL
{
	INT_PTR CALLBACK xrFSL::dlgProc( HWND hDlg, uint32 uiMsg, WPARAM wParam, LPARAM lParam )
	{
		// �������� ������ ��� ��������� ���������� �� ������
		static SAssertInfo* pAssertInfo = NULL;

		// ��������� ��������� �������
		switch(uiMsg)
		{
		case WM_INITDIALOG:			// �������������
			{
				pAssertInfo = (SAssertInfo*)lParam;

				// ��������� �����. ���� �������
				SetWindowText(GetDlgItem(hDlg, IDC_EDIT_CONDITION), pAssertInfo->sCondition.c_str());
				SetWindowText(GetDlgItem(hDlg, IDC_EDIT_FILE), pAssertInfo->sFile.c_str());

				// ������� ������ ������ � ��������� ��������
				char szLine[MAX_PATH];
				sprintf(szLine, "%d", pAssertInfo->uiLine);
				SetWindowText(GetDlgItem(hDlg, IDC_EDIT_LINE), szLine);

				// ��������� ������
				if(pAssertInfo->sMessage.c_str() && pAssertInfo->sMessage.c_str()[0] != '\0')
				{
					SetWindowText(GetDlgItem(hDlg, IDC_EDIT_REASON), pAssertInfo->sMessage.c_str());
				}
				else
				{
					SetWindowText(GetDlgItem(hDlg, IDC_EDIT_REASON), "No Reason");
				}

				// ������� �������
				SetWindowPos(hDlg, HWND_TOPMOST, pAssertInfo->uiX, pAssertInfo->uiY, 0, 0, SWP_SHOWWINDOW|SWP_NOSIZE);

				break;
			}

		case WM_COMMAND:
			{
				switch(LOWORD(wParam))
				{
				case IDCANCEL:
				case IDC_BUTTON_CONTINUE:
					{
						pAssertInfo->btnChosen = SAssertInfo::BUTTON_CONTINUE;
						EndDialog(hDlg, 0);
						break;
					}
				case IDC_BUTTON_IGNORE:
					{
						pAssertInfo->btnChosen = SAssertInfo::BUTTON_IGNORE;
						EndDialog(hDlg, 0);
						break;
					}
				case IDC_BUTTON_IGNORE_ALL:
					{
						pAssertInfo->btnChosen = SAssertInfo::BUTTON_IGNORE_ALL;
						EndDialog(hDlg, 0);
						break;
					}
				case IDC_BUTTON_BREAK:
					{
						pAssertInfo->btnChosen = SAssertInfo::BUTTON_BREAK;
						EndDialog(hDlg, 0);
						break;
					}
				case IDC_BUTTON_STOP:
					{
						pAssertInfo->btnChosen = SAssertInfo::BUTTON_STOP;
						EndDialog(hDlg, 1);
						break;
					}
				default:
					break;
				};
				break;
			}

		default:
			return FALSE;
		}
	}

	//-----------------------------------------------------------------------
	//
	//-----------------------------------------------------------------------
	xrFSL_CORE_API bool xrFSL::processingAssert(const String& sCondition, const String& sFile, uint32 uiLine, bool* pbIgnore, bool bFatal /* = false */)
	{
		// ��������� �����
		std::stringstream msg;
		msg << "\n*-*-* Assertion failed! *-*-*\n" 
			<< "Expression: " << sCondition << '\n'
			<< "File: " << sFile << '\n'
			<< "Line: " << uiLine << '\n'
			<< "Reason: " << gs_szMessage;  
		LOG(msg.str());

		// ���� �� ���� ������������ ������, ����� ������������
		if (pbIgnore)
		{
			// �������� ��������� � ����������� �� ������
			SAssertInfo assertInfo;

			assertInfo.sCondition	= sCondition;
			assertInfo.sFile		= sFile;
			assertInfo.uiLine		= uiLine;
			assertInfo.sMessage		= gs_szMessage;
			assertInfo.btnChosen	= SAssertInfo::BUTTON_CONTINUE;

			assertInfo.uiX = 10;
			assertInfo.uiY = 10;

			if (bFatal)
				DialogBoxIndirectParam(
				GetModuleHandle(NULL),
				(DLGTEMPLATE*)&gs_fatalDialogRC,
				GetDesktopWindow(),
				dlgProc,
				(LPARAM)&assertInfo);
			else
				DialogBoxIndirectParam(GetModuleHandle(NULL), (DLGTEMPLATE*)&gs_warnDialogRC, GetDesktopWindow(), dlgProc, (LPARAM)&assertInfo);

			// ������������ ������� �� ������� ������
			switch(assertInfo.btnChosen)
			{
			case SAssertInfo::BUTTON_IGNORE:		// ������������
				*pbIgnore = true;
				break;
			case SAssertInfo::BUTTON_IGNORE_ALL:	// ������������ ��
				*pbIgnore = true;
				break;
			case SAssertInfo::BUTTON_BREAK:			// ������� ����
				return true;
				break;
			case SAssertInfo::BUTTON_STOP:			// ���������� ����������
				exit(1);
				break;
			}	// switch end
		}	// if !pbIgnore end			
		return false;
	}

	//-----------------------------------------------------------------------
	//
	//-----------------------------------------------------------------------
	xrFSL_CORE_API void processMessage(const char* pszFormatMsg,...)
	{
		//if(!gEnv->bIgnoreAllAsserts)
		//{
			if(NULL == pszFormatMsg)
			{
				gs_szMessage[0] = '\0';
			}
			else
			{
				va_list args;
				va_start(args, pszFormatMsg);

				vsprintf(gs_szMessage, pszFormatMsg, args);

				va_end(args);
			}
		//}
	}
}