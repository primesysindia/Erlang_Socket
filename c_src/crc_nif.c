#include "erl_nif.h"

extern int foo(int x);
extern int bar(int y);

static ERL_NIF_TERM get_crc_nif(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
	ERL_NIF_TERM list = argv[0];
	unsigned int args_size;
	ERL_NIF_TERM head, tail;
	int i = 0,j;
	char source[100]={0};

	if (!enif_get_list_length(env, list, &args_size)) {
		return enif_make_badarg(env);    
	}

	int args[args_size];

	while(enif_get_list_cell(env, list, &head, &tail)) {
		if(!enif_get_int(env, head, &args[i])) {
			return enif_make_badarg(env);    
		}
		i++;
		list = tail;
	}

	for(j=0; j<args_size; j++)
	{
		source[j]=(char)args[j];
	}
	unsigned char a,b;
	int arr[2];
	
	getCrc(source, args_size,&a,&b);
	//printf("0x%0.2X 0x%0.2X",a,b);
	arr[0]=(int)a;
	arr[1]=(int)b;
	//printf("\nInt = %d \n",args_size);
	
	ERL_NIF_TERM ent_quartiles_array[2];
	ent_quartiles_array[0] = enif_make_int(env, arr[0]);
	ent_quartiles_array[1] = enif_make_int(env, arr[1]);

	ERL_NIF_TERM quartiles = enif_make_tuple_from_array(env, ent_quartiles_array, 2);

	return enif_make_tuple1(env, quartiles);

/*
    if (!enif_get_int(env, argv[0], &x)) {
	return enif_make_badarg(env);
    }

	return enif_make_int(env, x);
*/
//    ret = crc(x);
   // return enif_make_int(env, args_size);
}

static ErlNifFunc nif_funcs[] = {
    {"get_crc", 1, get_crc_nif}
};

ERL_NIF_INIT(crc, nif_funcs, NULL, NULL, NULL, NULL)
