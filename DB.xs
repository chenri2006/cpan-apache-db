#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#ifdef WIN32
#define SIGINT 2
#endif

/*
 * Reimplementation of Perl_init_debugger() using only public APIs.
 * The original became hidden (__attribute__visibility__("hidden"))
 * in Perl 5.37.1 and is no longer callable from XS code.
 */
static void my_init_debugger(pTHX)
{
    HV *ostash = PL_curstash;
    MAGIC *mg;

    PL_curstash = (HV *)SvREFCNT_inc_simple(PL_debstash);

    /* init_dbargs — also hidden, replicate inline */
    PL_dbargs = GvAV(gv_AVadd(
                    gv_fetchpvs("DB::args", GV_ADDMULTI, SVt_PVAV)));
    if (AvREAL(PL_dbargs)) {
        av_clear(PL_dbargs);
        AvREAL_off(PL_dbargs);
    }
    AvREIFY_only(PL_dbargs);

    PL_DBgv   = GvREFCNT_inc(
                    gv_fetchpvs("DB::DB", GV_ADDMULTI, SVt_PVGV));
    PL_DBline = GvREFCNT_inc(
                    gv_fetchpvs("DB::dbline", GV_ADDMULTI, SVt_PVAV));
    PL_DBsub  = GvREFCNT_inc(gv_HVadd(
                    gv_fetchpvs("DB::sub", GV_ADDMULTI, SVt_PVHV)));

    PL_DBsingle = GvSV(
                    gv_fetchpvs("DB::single", GV_ADDMULTI, SVt_PV));
    if (!SvIOK(PL_DBsingle))
        sv_setiv(PL_DBsingle, 0);
    mg = sv_magicext(PL_DBsingle, NULL, PERL_MAGIC_debugvar,
                     &PL_vtbl_debugvar, 0, 0);
    mg->mg_private = DBVARMG_SINGLE;
    SvSETMAGIC(PL_DBsingle);

    PL_DBtrace = GvSV(
                    gv_fetchpvs("DB::trace", GV_ADDMULTI, SVt_PV));
    if (!SvIOK(PL_DBtrace))
        sv_setiv(PL_DBtrace, 0);
    mg = sv_magicext(PL_DBtrace, NULL, PERL_MAGIC_debugvar,
                     &PL_vtbl_debugvar, 0, 0);
    mg->mg_private = DBVARMG_TRACE;
    SvSETMAGIC(PL_DBtrace);

    PL_DBsignal = GvSV(
                    gv_fetchpvs("DB::signal", GV_ADDMULTI, SVt_PV));
    if (!SvIOK(PL_DBsignal))
        sv_setiv(PL_DBsignal, 0);
    mg = sv_magicext(PL_DBsignal, NULL, PERL_MAGIC_debugvar,
                     &PL_vtbl_debugvar, 0, 0);
    mg->mg_private = DBVARMG_SIGNAL;
    SvSETMAGIC(PL_DBsignal);

    SvREFCNT_dec(PL_curstash);
    PL_curstash = ostash;
}

static Sighandler_t ApacheSIGINT = NULL;

MODULE = Apache::DB		PACKAGE = Apache::DB

PROTOTYPES: DISABLE

BOOT:
    ApacheSIGINT = rsignal_state(whichsig("INT"));

int
init_debugger()

    CODE:
    if (!PL_perldb) {
	PL_perldb = PERLDB_ALL;
	my_init_debugger(aTHX);
	RETVAL = TRUE;
    }
    else
	RETVAL = FALSE;

    OUTPUT:
    RETVAL

MODULE = Apache::DB            PACKAGE = DB

void
ApacheSIGINT(...)

    CODE:
#ifdef PERL_USE_3ARG_SIGHANDLER
    if (ApacheSIGINT) (*ApacheSIGINT)(SIGINT, NULL, NULL);
#else
    if (ApacheSIGINT) (*ApacheSIGINT)(SIGINT);
#endif
