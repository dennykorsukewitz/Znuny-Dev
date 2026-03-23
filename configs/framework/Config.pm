
    $Self->{'SecureMode'}                        = 1;
    $Self->{'SystemID'}                          = '42';
    $Self->{'SessionName'}                       = '{{FRAMEWORK}}';
    $Self->{'ProductName'}                       = '{{FRAMEWORK}}';
    $Self->{'ScriptAlias'}                       = '{{FRAMEWORK}}/';
    $Self->{'Frontend::WebPath'}                 = '/{{FRAMEWORK}}-web/';
    $Self->{'CheckEmailAddresses'}               = 0;
    $Self->{'CheckMXRecord'}                     = 0;
    $Self->{'Organization'}                      = '';
    $Self->{'LogModule'}                         = 'Kernel::System::Log::File';
    $Self->{'LogModule::LogFile'}                = '{{FRAMEWORK_DIR}}{{FRAMEWORK}}/var/log/znuny.log';

    $Self->{'FQDN'}                              = 'localhost';
    $Self->{'Port'}                              = '{{PORT}}';
    $Self->{'DefaultLanguage'}                   = 'de';
    $Self->{'DefaultCharset'}                    = 'utf-8';
    $Self->{'AdminEmail'}                        = 'root\@localhost';
    $Self->{'Package::Timeout'}                  = '120';
    $Self->{'SendmailModule'}                    =  'Kernel::System::Email::DoNotSendEmail';
    $Self->{'SwitchToAgent'}                     = 1;
    $Self->{'SwitchToCustomer'}                  = 1;

    # Fred
    $Self->{'Fred'}->{'Active'}          = '1';
    $Self->{'Fred'}->{'BackgroundColor'} = '#006ea5';
    $Self->{'Fred'}->{'SystemName'}      = '{{FRAMEWORK}}';
    $Self->{'Fred'}->{'ConsoleOpacity'}  = '0.7';
    $Self->{'Fred'}->{'ConsoleWidth'}    = '30%';
    $Self->{'Fred'}->{'ConsoleHeight'}   = '200px';
    $Self->{'Fred'}->{'LogPath'}         = 'var/log/';

    # Misc
    $Self->{'Loader::Enabled::CSS'}  = 0;
    $Self->{'Loader::Enabled::JS'}   = 0;

    # Ticket::Frontend::AgentTicketNote
    $Self->{'Ticket::Frontend::AgentTicketNote'}->{'Body'}                        = 'Test Body';
    $Self->{'Ticket::Frontend::AgentTicketNote'}->{'DynamicField'}                = {};
    $Self->{'Ticket::Frontend::AgentTicketNote'}->{'FormDraft'}                   = '1';
    $Self->{'Ticket::Frontend::AgentTicketNote'}->{'HistoryComment'}              = '%%Note';
    $Self->{'Ticket::Frontend::AgentTicketNote'}->{'HistoryType'}                 = 'AddNote';
    $Self->{'Ticket::Frontend::AgentTicketNote'}->{'InformAgent'}                 = 1;
    $Self->{'Ticket::Frontend::AgentTicketNote'}->{'InvolvedAgent'}               = 1;
    $Self->{'Ticket::Frontend::AgentTicketNote'}->{'IsVisibleForCustomerDefault'} = 1;
    $Self->{'Ticket::Frontend::AgentTicketNote'}->{'Note'}                        = '1';
    $Self->{'Ticket::Frontend::AgentTicketNote'}->{'NoteMandatory'}               = '1';
    $Self->{'Ticket::Frontend::AgentTicketNote'}->{'Owner'}                       = 1;
    $Self->{'Ticket::Frontend::AgentTicketNote'}->{'OwnerMandatory'}              = 1;
    $Self->{'Ticket::Frontend::AgentTicketNote'}->{'Permission'}                  = 'note';
    $Self->{'Ticket::Frontend::AgentTicketNote'}->{'Priority'}                    = 1;
    $Self->{'Ticket::Frontend::AgentTicketNote'}->{'Queue'}                       = 1;
    $Self->{'Ticket::Frontend::AgentTicketNote'}->{'QueueMandatory'}              = 1;
    $Self->{'Ticket::Frontend::AgentTicketNote'}->{'RequiredLock'}                = 1;
    $Self->{'Ticket::Frontend::AgentTicketNote'}->{'Responsible'}                 = 1;
    $Self->{'Ticket::Frontend::AgentTicketNote'}->{'ResponsibleMandatory'}        = 1;
    $Self->{'Ticket::Frontend::AgentTicketNote'}->{'RichTextHeight'}              = '100px';
    $Self->{'Ticket::Frontend::AgentTicketNote'}->{'RichTextWidth'}               = '100%';
    $Self->{'Ticket::Frontend::AgentTicketNote'}->{'Service'}                     = 1;
    $Self->{'Ticket::Frontend::AgentTicketNote'}->{'ServiceMandatory'}            = 1;
    $Self->{'Ticket::Frontend::AgentTicketNote'}->{'SLAMandatory'}                = 1;
    $Self->{'Ticket::Frontend::AgentTicketNote'}->{'State'}                       = 1;
    $Self->{'Ticket::Frontend::AgentTicketNote'}->{'StateMandatory'}              = 1;
    $Self->{'Ticket::Frontend::AgentTicketNote'}->{'Subject'}                     = 'Test Subject';
    $Self->{'Ticket::Frontend::AgentTicketNote'}->{'TicketType'}                  = 1;
    $Self->{'Ticket::Frontend::AgentTicketNote'}->{'Title'}                       = 1;
    $Self->{'Ticket::Frontend::AgentTicketNote'}->{'StateType'}                   = [
        'open',
        'closed',
        'pending reminder',
        'pending auto'
    ];
