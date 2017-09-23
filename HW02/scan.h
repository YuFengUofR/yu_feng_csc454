#ifndef MYSCAN_H
#define MYSCAN_H

#include <iostream>
#include <string>
#include <cctype>

using namespace std;

enum token {t_read, t_write, t_id, t_literal, t_gets,
    t_add, t_sub, t_mul, t_div, t_lparen, t_rparen, t_eof,
    t_if, t_fi, t_do, t_od, t_check, t_equal, t_comp, t_less,
    t_greater, t_lequal, t_gequal
};

static string token_image;
static char c;

class myScan
{
public:
    myScan();
    ~myScan();
    static token scan();
    static const string get_token_image();
    
};


#endif